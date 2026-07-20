import pygame
import serial
import numpy as np
import sys
#this code is used to draw the number on a laptop, and then send the byte data through uart to microblaze and puts it into the ddr3 where 
the dma sends this data to the npu

COM_PORT  = 'COM3' #com port
BAUD_RATE = 115200


#tries to open the serial port, if it fails it will print an error statement so that we know that it didn't work
try:
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    print(f"Successfully connected to FPGA on {COM_PORT}")
except Exception as e:
    print(f"Error opening {COM_PORT}")
    sys.exit()

#scale the window to 280 x 280 so that its big enough to draw on
pygame.init()
WIDTH = 280
HEIGHT= 280
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Draw a Number (ENTER to send, C to clear)") 

canvas = np.zeros((28, 28), dtype=np.uint8) #2d array to hold the values of the pixel (0-black to 255-white), 1byte per pixel
drawing = False

def draw_brush(x, y):
    # Scale 280x280 mouse coordinates down to 28x28 array
    grid_x, grid_y = x // 10, y // 10
    # center of mouse is white with the surroundings fading into gray, this is how the model is trained so NPU accuracy is improved
    if 0 <= grid_x < 28 and 0 <= grid_y < 28:
        canvas[grid_y, grid_x] = 255
        if grid_y > 0 and canvas[grid_y-1, grid_x] < 128: canvas[grid_y-1, grid_x] = 128
        if grid_y < 27 and canvas[grid_y+1, grid_x] < 128: canvas[grid_y+1, grid_x] = 128
        if grid_x > 0 and canvas[grid_y, grid_x-1] < 128: canvas[grid_y, grid_x-1] = 128
        if grid_x < 27 and canvas[grid_y, grid_x+1] < 128: canvas[grid_y, grid_x+1] = 128

running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

        #draw if the mouse is clicked
        elif event.type == pygame.MOUSEBUTTONDOWN:
            drawing = True
            draw_brush(*event.pos)
            
        elif event.type == pygame.MOUSEBUTTONUP:
            drawing = False
            
        elif event.type == pygame.MOUSEMOTION and drawing:
            draw_brush(*event.pos)
            
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_c:
                canvas.fill(0) # clears the array
            
            elif event.key == pygame.K_RETURN:
                #uses ready bits
                payload = bytearray([0xAA, 0xBB]) + bytearray(canvas.flatten()) #converts 2d array to 1d
                ser.write(payload) #gives to uart
                print("Sent! Check the HDMI Screen")

    #render the screen
    screen.fill((0, 0, 0))
    for y in range(28):
        for x in range(28):
            color = canvas[y, x]
            pygame.draw.rect(screen, (color, color, color), (x*10, y*10, 10, 10))
            
    pygame.display.flip()

ser.close()
pygame.quit()
