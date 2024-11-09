# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

#global asic_in_state#can't set 1 bit at a time, and reading in.io.value always returns the state from the previous clock cycle, so need to retain new state locally and set on every wait operation

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    global asic_in_state
    asic_in_state=0;
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await asic_sleep(dut,10)#await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    set_io(dut,"cs",1)#cs, active low, inactive high
    set_io(dut,"spi_clk",0)#MODE 0

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    #dut.ui_in.value = 20
    #dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    dut._log.info("dut.uio_out.value: "+str(dut.uio_out.value)+" "+str(dut.uio_out.value.__class__))
    dut._log.info("dut.uio_oe.value: "+str(dut.uio_oe.value)+" "+str(dut.uio_oe.value.__class__))
    dut._log.info("dut.uo_out.value: "+str(dut.uo_out.value)+" "+str(dut.uo_out.value.__class__))
    #assert int(dut.uio_out.value) & int(dut.uio_oe.value) == 0

    #dut._log.info("enable out")
    #for iter in range(68):
    #    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    #    dut._log.info(str(dut.uio_oe.value)+" "+str(dut.uio_out.value))
    #    if(iter==63): dut._log.info("--")
        
    dut._log.info("dut.uo_out")
    for iter in range(10):
        await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
        #print(format(int(dut.uo_out.value), '08b'))
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    set_io(dut,"cs",1)
    #dut.ui_in.value = 1;
    dut._log.info("cs=1")
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    set_io(dut,"cs",0)
    dut._log.info("cs=0")
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    for iter in range(10):
        await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
        #print(format(int(dut.uo_out.value), '08b'))
        
    for out_value in []:#[0x5E,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0xFF,0x00,0x00,0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0xC5,0x5C,0xF0,0x1D,0xAB,0x1E]:
        reg_addr=0x00
        await exchange_spi_byte(dut,reg_addr,out_value,1)
        #dut._log.info("write: "+str(hex(out_value)))
        spi_readback = await exchange_spi_byte(dut,reg_addr,0x00,0)
        #dut._log.info("spi_readback: "+str(hex(spi_readback)))
        dut._log.info("loopback reg "+str(hex(reg_addr))+": "+str(hex(out_value))+" "+str(hex(spi_readback))+("\tPASS" if out_value==spi_readback else "\tFAIL"))
    
    for reg_addr in []:#range(24):
        out_value=0x1E+reg_addr
        await exchange_spi_byte(dut,reg_addr,out_value,1)
        spi_readback = await exchange_spi_byte(dut,reg_addr,0x00,0)
        is_pass=out_value==spi_readback
        if(reg_addr==23): is_pass=spi_readback==0xE5;
        dut._log.info("extended reg "+str(hex(reg_addr))+": write: "+str(hex(out_value))+", read: "+str(hex(spi_readback))+("\tPASS" if is_pass else "\tFAIL"))
        assert is_pass
    
    #await exchange_spi_byte(dut,21,0x83,1)
    await set_print_charlie(dut,2,0)
        
    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.

#index 0 is MSbit, 7 is LSbit
def get_bit(value,index):
    return (value >> (7-index)) & 1

async def set_print_charlie(dut,frame_index,is_mirror):
    await exchange_spi_byte(dut,19,frame_index|(is_mirror<<2),1)
    charlie=await get_charlie(dut)
    print_charlie(dut,charlie,is_mirror)

async def get_charlie(dut):
    out=[[0 for col in range(8)] for row in range(8)]
    for iter in range(64):
        await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
        row=get_charlie_bi_en_bit(dut,1)
        col=get_charlie_bi_en_bit(dut,0)
        if(not row==col):
            out[row][col]=1;
            
        #print(str(dut.uio_oe.value)+" "+str(dut.uio_out.value))
    return out

def get_charlie_bi_en_bit(dut,is_row):
    enabled=dut.uio_oe.value
    row_power=dut.uio_out.value
    idx_list=list(range(8))
    for iter in idx_list:
        if((enabled>>iter)&0x01 and (((row_power>>iter)&0x01)==is_row)): return iter
    return -1

def print_charlie(dut,charlie,is_mirror=False):
    dut._log.info(" 76543210 ")
    dut._log.info("+"+"-"*8+"+")
    for row in range(8):
        line=""
        for col in range(8):
            if(row==col):
                if(is_mirror): line+="x"
                else: line="x"+line
            elif(charlie[row][col]): 
                if(is_mirror): line+="."
                else: line="."+line
            else:
                if(is_mirror): line+=" "
                else: line=" "+line
        line="|"+line+"|"+str(row)
        dut._log.info(line)
    dut._log.info("+"+"-"*8+"+")
    dut._log.info(" 76543210 ")

#CPHA=0
async def exchange_spi_byte(dut,address,mosi_value,is_write):
    set_io(dut,"cs",0)
    #await ClockCycles(dut.clk, 1)
    set_io(dut,"spi_clk",0)
    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    miso_value=0;
    if(is_write): address=address|0x80;#MSbit is is_write MOSI
    else: address=address&0x7F;#read MISO
    for byte_index in range(2):
        is_address=byte_index==0
        for iter in range(8):
            mosi_bit=get_bit(address if is_address else mosi_value,iter)
            #dut._log.info("mosi_bit: "+str(mosi_bit))
            set_io(dut,"mosi",mosi_bit)#write new value on falling edge
            #await ClockCycles(dut.clk, 1)
            set_io(dut,"spi_clk",0)#spi_clk
            await asic_sleep(dut,5)#await ClockCycles(dut.clk, 5)
            set_io(dut,"spi_clk",1)#spi_clk
            if(not is_address):#read on rising edge
                miso_value=miso_value<<1;
                
                #dut._log.info("dut.uo_out.value: "+str(dut.uo_out.value))
                if(get_io(dut,"miso")): miso_value|=0x01;
            await asic_sleep(dut,5)#await ClockCycles(dut.clk, 5)
    set_io(dut,"cs",1)#cs
    #await ClockCycles(dut.clk, 1)
    set_io(dut,"spi_clk",0)#spi_clk
    await asic_sleep(dut,10)#await ClockCycles(dut.clk, 10)
    return miso_value
    
async def asic_sleep(dut,cycles):
    global asic_in_state
    dut.ui_in.value=asic_in_state
    await ClockCycles(dut.clk, cycles)
    asic_in_state=dut.ui_in.value
    
#note: reading dut.ui_in.value shows the value from the previous clock cycle, regardless of changes during this clock cycle
#to see an updated dut.ui_in.value, wait 1 clock cycle
def set_io(dut,name,value):
    index=0;
    if(not value in [0,1]): raise ValueError("Invalid binary value: "+str(value))
    match(name):
        case "cs":          index=0
        case "spi_clk":     index=1
        case "mosi":        index=2
        case "is_simulate": index=3
        case "debug_in_0":  index=4
        case "debug_in_1":  index=5
        case "debug_in_2":  index=6
        case "debug_in_3":  index=7
        case _: raise ValueError("DUT IO name not found: "+name)
    #dut._log.info("set_io A: "+format(int(dut.ui_in.value), '08b')+" "+str(value)+" "+str(index)+" "+name)
    #if(value): dut.ui_in.value= dut.ui_in.value | (1<<index) #FYI, |= and &= write erroneous values
    #else: dut.ui_in.value= dut.ui_in.value & (~(1 << index))
    global asic_in_state
    if(value): asic_in_state= asic_in_state | (1<<index) #FYI, |= and &= write erroneous values
    else: asic_in_state= asic_in_state & (~(1 << index))
    #await ClockCycles(dut.clk, 1)
    #dut._log.info("set_io B: "+format(~(1 << index), '08b'))
    #dut._log.info("set_io B: "+format(int(dut.ui_in.value), '08b'))
        
def get_io(dut,name):
    match(name):
        case "led_0": index=0
        case "led_1": index=1
        case "led_2": index=2
        case "led_3": index=3
        case "led_4": index=4
        case "led_5": index=5
        case "led_6": index=6
        case "miso":  index=7
        case _: raise ValueError("DUT IO name not found: "+name)
    return (dut.uo_out.value>>index)&0x01
