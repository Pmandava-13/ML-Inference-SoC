"""
 MNIST MLP Trainer → FPGA COE Exporter & C Header Exporter
this python script trains a 2 layer neural network to recognize digits (0-9) from the MNIST data set.
once it finishes training, it converts the weights that have floating points into integers and packages them into
a .coe file that has 512 bit rows for the NPU's BRAM and a .h file that uses standard C arrays for the Microblaze to use
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import numpy as np


SCALE  = 256 #this scale is the same thing as left shifting by 8 bits, used to convert decimals to integers
EPOCHS = 15 #number of times it trains
LR     = 0.001 #learning rate, how hard the model corrects for errors
BATCH  = 128 #batch size

# totensor converts images to pixels that range from 0-1, cannot normalize this because the hardware expects un-normalizes 8 bit values
transform     = transforms.ToTensor()
train_dataset = datasets.MNIST('./data', train=True,  download=True, transform=transform)
test_dataset  = datasets.MNIST('./data', train=False, download=True, transform=transform)
train_loader  = DataLoader(train_dataset, batch_size=BATCH, shuffle=True)
test_loader   = DataLoader(test_dataset,  batch_size=BATCH, shuffle=False)


class MLP(nn.Module):
    def __init__(self):
        super().__init__()
      #no bias terms because we don't have the bram space for all that and also makes hardware faster
        self.fc1 = nn.Linear(784, 64, bias=False) #layer 1: input -> hidden layer
        self.fc2 = nn.Linear(64,  10, bias=False) #layer 2: hidden layer-> outputs

    def forward(self, x):
        x = x.view(-1, 784) #flatted 28x28 into 1d array
        x = torch.relu(self.fc1(x)) #relu activation
        return self.fc2(x) #no activation for outputs
#uses gpu if it has cuda drivers for training if its available, otherwise it uses cpu
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')  
model  = MLP().to(device)
print(f"Device: {device}")

optimizer = optim.Adam(model.parameters(), lr=LR) #uses the adam optimizer for tweaking training parameters
criterion = nn.CrossEntropyLoss() #uses cross entropy loss for loss functions

def test_accuracy():
    model.eval() 
    correct = 0
    with torch.no_grad():
        for x, y in test_loader:
            x, y = x.to(device), y.to(device)
            correct += (model(x).argmax(1) == y).sum().item()
    return correct / len(test_loader.dataset)

#training loop and sets the model to training
for epoch in range(1, EPOCHS + 1):
    model.train()
    total_loss = 0.0
    for x, y in train_loader:
        x, y = x.to(device), y.to(device)
        optimizer.zero_grad()
        loss = criterion(model(x), y)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    acc = test_accuracy()
    print(f"Epoch {epoch:02d}/{EPOCHS}  loss {total_loss/len(train_loader):.4f}  test {acc*100:.2f}%")
  #the statement above lets us see the status of the training and see how wells its being trained

# turns the floating points into integers by multiplying them by 256 and casts it into a 32 bit signed integer
model.cpu().eval()
w1 = (model.fc1.weight.detach() * SCALE).round().to(torch.int32)  # (64, 784)
w2 = (model.fc2.weight.detach() * SCALE).round().to(torch.int32)  # (10, 64)



w1_np = w1.numpy()
w2_np = w2.numpy()

#simulation/sanity check, we want to make sure that the math actually works and that quantization didn't break the accuracy of the model
raw_test = datasets.MNIST('./data', train=False, transform=transforms.ToTensor())
correct_q = 0
for img, label in raw_test:
    pixels = (img.numpy() * 255).round().astype(np.uint8).flatten()
    x      = pixels.astype(np.int64)
    hidden = np.maximum(0, (w1_np.astype(np.int64) @ x) >> 8)
    logits = w2_np.astype(np.int64) @ hidden
    if np.argmax(logits) == label:
        correct_q += 1

float_acc = test_accuracy()
quant_acc = correct_q / len(raw_test)
print(f"\nFloat  accuracy : {float_acc*100:.2f}%")
print(f"Quant. accuracy : {quant_acc*100:.2f}%  <- what hardware will prolly achieve")

#exports the weights into a coe file that matches how the hardware expects the weights to be packaged (512 bits per row)
coe_weights = []
  #layer 1 weight packaging
for p_idx in range(4):
    for px in range(784):
        coe_weights.extend(w1[p_idx*16 : p_idx*16+16, px].tolist())
#layer 2 weight packaging
for n in range(64):
    coe_weights.extend(w2[:, n].tolist() + [0, 0, 0, 0, 0, 0])

assert len(coe_weights) == 3200 * 16

coe_file = "npu_weights.coe"
with open(coe_file, 'w') as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")

    for i in range(0, len(coe_weights), 16):
        row  = ''.join(f"{int(v) & 0xFFFFFFFF:08X}" for v in coe_weights[i:i+16])
        term = ';' if (i + 16 >= len(coe_weights)) else ','
        f.write(row + term + '\n')




#this does the same thing but for the microblaze and turns the quantized weights into a standard C array for the microblaze, we will import 
#this header file into the vitis project.

with open("npu_weights.h", "w") as f:
    f.write("#ifndef NPU_WEIGHTS_H\n#define NPU_WEIGHTS_H\n\n")
    f.write("#include <stdint.h>\n\n")
    
    # Write Layer 1 Weights (64x784) - Extracted straight from w1_np
    f.write("const int32_t cpu_l1_weights[64][784] = {\n")
    for i in range(64):
        row_str = ", ".join(map(str, w1_np[i]))
        f.write(f"    {{ {row_str} }}")
        f.write(",\n" if i < 63 else "\n")
    f.write("};\n\n")
    
    # Write Layer 2 Weights (10x64) - Extracted straight from w2_np
    f.write("const int32_t cpu_l2_weights[10][64] = {\n")
    for i in range(10):
        row_str = ", ".join(map(str, w2_np[i]))
        f.write(f"    {{ {row_str} }}")
        f.write(",\n" if i < 9 else "\n")
    f.write("};\n\n")
    
    f.write("#endif\n")

print("npu_weights.h generated")
