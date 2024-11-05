# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

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
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await set_io(dut,"cs",1)#cs, active low, inactive high
    await set_io(dut,"spi_clk",0)#MODE 0

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    #dut.ui_in.value = 20
    #dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    dut._log.info("dut.uio_out.value: "+str(dut.uio_out.value)+" "+str(dut.uio_out.value.__class__))
    dut._log.info("dut.uio_oe.value: "+str(dut.uio_oe.value)+" "+str(dut.uio_oe.value.__class__))
    dut._log.info("dut.uo_out.value: "+str(dut.uo_out.value)+" "+str(dut.uo_out.value.__class__))
    #assert int(dut.uio_out.value) & int(dut.uio_oe.value) == 0

    dut._log.info("enable out")
    for iter in range(68):
        await ClockCycles(dut.clk, 1)
        print(str(dut.uio_oe.value)+" "+str(dut.uio_out.value))
        if(iter==63): dut._log.info("--")
        
    dut._log.info("dut.uo_out")
    for iter in range(10):
        await ClockCycles(dut.clk, 1)
        print(format(int(dut.uo_out.value), '08b'))
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await ClockCycles(dut.clk, 1)
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await set_io(dut,"cs",1)
    dut._log.info("cs=1")
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await ClockCycles(dut.clk, 1)
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await set_io(dut,"cs",0)
    dut._log.info("cs=0")
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    await ClockCycles(dut.clk, 1)
    dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    for iter in range(10):
        await ClockCycles(dut.clk, 1)
        print(format(int(dut.uo_out.value), '08b'))
        
    for out_value in []:#0x5E,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0xFF,0x00,0x00,0x00,0xC5,0x5C,0xF0,0x1D,0xAB,0x1E]:
        await exchange_spi_byte(dut,0x00,out_value,1);
        #dut._log.info("write: "+str(hex(out_value)))
        spi_readback = await exchange_spi_byte(dut,0x00,out_value,0);
        #dut._log.info("spi_readback: "+str(hex(spi_readback)))
        dut._log.info("loopback: "+str(hex(out_value))+" "+str(hex(spi_readback))+("\tPASS" if out_value==spi_readback else "\tFAIL"))

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.

#index 0 is MSbit, 7 is LSbit
def get_bit(value,index):
    return (value >> (7-index)) & 1

#CPHA=0
async def exchange_spi_byte(dut,address,mosi_value,is_write):
    await set_io(dut,"cs",0)
    await set_io(dut,"spi_clk",0)
    miso_value=0;
    if(is_write): address=address|0x80;#MSbit is is_write MOSI
    else: address=address&0x7F;#read MISO
    for byte_index in range(2):
        is_address=byte_index==0
        for iter in range(8):
            mosi_bit=get_bit(address if is_address else mosi_value,iter)
            #dut._log.info("mosi_bit: "+str(mosi_bit))
            await set_io(dut,"mosi",mosi_bit)#write new value on falling edge
            await set_io(dut,"spi_clk",0)#spi_clk
            await ClockCycles(dut.clk, 5)
            await set_io(dut,"spi_clk",1)#spi_clk
            if(not is_address):#read on rising edge
                miso_value=miso_value>>1;
                if(get_io(dut,"miso")): miso_value|=0x80;
            await ClockCycles(dut.clk, 5)
    await set_io(dut,"cs",1)#cs
    await set_io(dut,"spi_clk",0)#spi_clk
    await ClockCycles(dut.clk, 10)
    return miso_value
    
#note: reading dut.ui_in.value shows the value from the previous clock cycle, regardless of changes during this clock cycle
#to see an updated dut.ui_in.value, wait 1 clock cycle
async def set_io(dut,name,value):
    index=0;
    if(not value in [0,1]): raise ValueError("Invalid binary value: "+str(value))
    match(name):
        case "cs":         index=0
        case "spi_clk":    index=1
        case "mosi":       index=2
        case "wave_in":    index=3
        case "debug_in_0": index=4
        case "debug_in_1": index=5
        case "debug_in_2": index=6
        case "debug_in_3": index=7
        case _: raise ValueError("DUT IO name not found: "+name)
    dut._log.info("set_io A: "+format(int(dut.ui_in.value), '08b')+" "+str(value)+" "+str(index)+" "+name)
    if(value): dut.ui_in.value|=1<<index
    else: dut.ui_in.value&= ~(1 << index)
    await ClockCycles(dut.clk, 1)
    #dut._log.info("set_io B: "+format(~(1 << index), '08b'))
    dut._log.info("set_io B: "+format(int(dut.ui_in.value), '08b'))
        
def get_io(dut,name):
    match(name):
        case "miso":        index=0
        case "pwm_clock":   index=1
        case "wave_out_0":  index=2
        case "wave_out_1":  index=3
        case "debug_out_0": index=4
        case "debug_out_1": index=5
        case "debug_out_2": index=6
        case "debug_out_3": index=7
        case _: raise ValueError("DUT IO name not found: "+name)
    return (dut.uo_out.value>>index)&1
