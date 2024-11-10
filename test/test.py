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
    #asic_in_state=0;
    #dut._log.info("Reset")
    #dut.ena.value = 1
    #dut.ui_in.value = 0
    #dut.uio_in.value = 0
    #dut.rst_n.value = 0
    #await asic_sleep(dut,10)#await ClockCycles(dut.clk, 10)
    #dut.rst_n.value = 1
    #set_io(dut,"cs",1)#cs, active low, inactive high
    #set_io(dut,"spi_clk",0)#MODE 0
    await do_reset(dut)

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    #dut.ui_in.value = 20
    #dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    #dut._log.info("dut.uio_out.value: "+str(dut.uio_out.value)+" "+str(dut.uio_out.value.__class__))
    #dut._log.info("dut.uio_oe.value: "+str(dut.uio_oe.value)+" "+str(dut.uio_oe.value.__class__))
    #dut._log.info("dut.uo_out.value: "+str(dut.uo_out.value)+" "+str(dut.uo_out.value.__class__))
    #assert int(dut.uio_out.value) & int(dut.uio_oe.value) == 0

    #dut._log.info("enable out")
    #for iter in range(68):
    #    await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    #    dut._log.info(str(dut.uio_oe.value)+" "+str(dut.uio_out.value))
    #    if(iter==63): dut._log.info("--")
        
    # dut._log.info("dut.uo_out")
    # for iter in range(10):
        # await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
        # #print(format(int(dut.uo_out.value), '08b'))
    # dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    # await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    # dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    # set_io(dut,"cs",1)
    # #dut.ui_in.value = 1;
    # dut._log.info("cs=1")
    # dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    # await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    # dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    # set_io(dut,"cs",0)
    # dut._log.info("cs=0")
    # dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    # await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
    # dut._log.info("dut.ui_in.value: "+format(int(dut.ui_in.value), '08b'))
    # for iter in range(10):
        # await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
        # #print(format(int(dut.uo_out.value), '08b'))
        
        
    await test_spi(dut)
    await test_echo(dut)#echo inputs direct to outputs
    await test_decode(dut)#lookup table
    await test_sig_gen(dut)
        
    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.

async def test_sig_gen(dut):
    await do_reset(dut)
    dut._log.info("test_sig_gen")
    set_io(dut,"trigger",0)
    await exchange_spi_byte(dut,16,0b00100000,1)#clk div to run at max speed
    #await exchange_spi_byte(dut,16,0b00000001,1)#clk div = sys_clk /4
    await exchange_spi_byte(dut,19,0b00000010,1)#set mux output to the clock signals, set screen to show timestamps
    await exchange_spi_byte(dut,22,0b00000010,1)#set mux output to the sig gen signals
    await exchange_spi_byte(dut,18,3,1)#sig gen sleep for 3 clk_div ticks (sys_clk/2 by default)
    await exchange_spi_byte(dut,17,3,1)#bits of data (+1 sleep period)
    await exchange_spi_byte(dut,0,0xAA,1)#string of 1/0s the show
    await exchange_spi_byte(dut,1,0xCC,1)
    await exchange_spi_byte(dut,2,0x55,1)
    #await exchange_spi_byte(dut,20,0b00111111,1)#trigger either edge, recor time stamp, loop
    #await exchange_spi_byte(dut,20,0b00111101,1)#single snapshot
    await exchange_spi_byte(dut,20,0b00111110,1)#single snapshot
    print_in_out_state(dut,True)
    for iter in range(8):
        print_in_out_state(dut)
        await asic_sleep(dut,1)
    set_io(dut,"trigger",1)
    for iter in range(30):
        print_in_out_state(dut)
        await asic_sleep(dut,1)
    set_io(dut,"trigger",0)
    for iter in range(30):
        print_in_out_state(dut)
        await asic_sleep(dut,1)
    
    rising_timestamp=await get_timestamp(dut,False)
    falling_timestamp=await get_timestamp(dut,True)
    assert falling_timestamp>rising_timestamp
        
    set_io(dut,"trigger",1)
    for iter in range(20):
        print_in_out_state(dut)
        await asic_sleep(dut,1)
        
    rising_timestamp=await get_timestamp(dut,False)
    assert rising_timestamp>falling_timestamp
    
    triggers_seen=await exchange_spi_byte(dut,21,0,0)#single snapshot
    assert triggers_seen==3
    
    await exchange_spi_byte(dut,0,0x5E,1)
    await exchange_spi_byte(dut,1,0x55,1)
    await exchange_spi_byte(dut,2,0x55,1)
    await exchange_spi_byte(dut,3,0x55,1)
        
    #note: this charlie clears the mega mux output
    await set_print_charlie(dut,1,0)
    await set_print_charlie(dut,1,1)
    await exchange_spi_byte(dut,19,0b10000010,1)#set mux output to the clock and sig gen signals, set screen to show timestamps
    await exchange_spi_byte(dut,18,200,1)#sig gen sleep for 3 clk_div ticks (sys_clk/2 by default)
    await exchange_spi_byte(dut,17,16*8-1,1)#bits of data (+1 sleep period)
    
    set_io(dut,"trigger",0)
    for iter in range(16*8+230):
        print_in_out_state(dut)
        await asic_sleep(dut,1)
        
    #test capture snapshot timestamp
    #test WS2812
    #test UART
    #test PWM
    
async def get_timestamp(dut,is_falling):
    out=0
    for iter in range(4):
        addr=8+is_falling*4+iter
        val=await exchange_spi_byte(dut,addr,0,0)
        out|=val<<(iter*8)#addr 8 is LSB, 11 is MSB
    return out

async def test_spi(dut):
    await do_reset(dut)
    for out_value in [0x5E,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0xFF,0x00,0x00,0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0xC5,0x5C,0xF0,0x1D,0xAB,0x1E]:
        reg_addr=0x00
        await exchange_spi_byte(dut,reg_addr,out_value,1)
        #dut._log.info("write: "+str(hex(out_value)))
        spi_readback = await exchange_spi_byte(dut,reg_addr,0x00,0)
        #dut._log.info("spi_readback: "+str(hex(spi_readback)))
        is_pass=out_value==spi_readback
        dut._log.info("loopback reg "+str(hex(reg_addr))+": write: "+str(hex(out_value))+" read: "+str(hex(spi_readback))+("\tPASS" if is_pass else "\tFAIL"))
        assert is_pass
    
    for reg_addr in range(24):
        out_value=0x1E+reg_addr
        await exchange_spi_byte(dut,reg_addr,out_value,1)
        spi_readback = await exchange_spi_byte(dut,reg_addr,0x00,0)
        is_pass=out_value==spi_readback
        if(reg_addr==23): is_pass=spi_readback==0xE5;
        dut._log.info("extended reg "+str(hex(reg_addr))+": write: "+str(hex(out_value))+", read: "+str(hex(spi_readback))+("\tPASS" if is_pass else "\tFAIL"))
        assert is_pass
    

async def do_reset(dut):
    global asic_in_state
    asic_in_state=0;
    dut._log.info("-- Reset --")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await asic_sleep(dut,10)#await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    set_io(dut,"cs",1)#cs, active low, inactive high
    set_io(dut,"spi_clk",0)#MODE 0

async def test_decode(dut):
    await do_reset(dut)
    for iter in range(16):#fill frame buffer
        value=((15-iter)<<4)|iter
        await exchange_spi_byte(dut,iter,value,1)
    await asic_sleep(dut,1)
    await set_print_charlie(dut,0,0)
    await set_print_charlie(dut,0,1)
    await set_print_charlie(dut,1,0)
    await set_print_charlie(dut,1,1)
    await exchange_spi_byte(dut,22,1,1)#set to decode mode
    print_in_out_state(dut,True)
    list_order=list(range(16))
    #list_order.reverse()
    for iter in list_order:#fill frame buffer
        in_val=(((15-iter)<<4)|iter)&0x7F
        asic_3=(iter>>3)&1
        asic_2=(iter>>2)&1
        asic_1=(iter>>1)&1
        asic_0=(iter>>0)&1
        set_io(dut,"asic_in_3",asic_3);
        set_io(dut,"asic_in_2",asic_2);
        set_io(dut,"asic_in_1",asic_1);
        set_io(dut,"asic_in_0",asic_0);
        await asic_sleep(dut,1)
        print_in_out_state(dut)
        out_val=dut.uo_out.value&0x7F;
        assert(in_val==out_val)
        
    

async def test_echo(dut):
    await do_reset(dut)
    print_in_out_state(dut,True)
    for iter in range(16):
        asic_3=(iter>>3)&1
        asic_2=(iter>>2)&1
        asic_1=(iter>>1)&1
        asic_0=(iter>>0)&1
        set_io(dut,"asic_in_3",asic_3);
        set_io(dut,"asic_in_2",asic_2);
        set_io(dut,"asic_in_1",asic_1);
        set_io(dut,"asic_in_0",asic_0);
        await asic_sleep(dut,1)
        print_in_out_state(dut)
        assert get_io(dut,"asic_out_6")==asic_3
        assert get_io(dut,"asic_out_5")==asic_2
        assert get_io(dut,"asic_out_4")==asic_1
        assert get_io(dut,"asic_out_3")==asic_0
    set_io(dut,"asic_in_3",0);
    set_io(dut,"asic_in_2",0);
    set_io(dut,"asic_in_1",0);
    set_io(dut,"asic_in_0",0);
    for rep in range(8):
        in_3=(rep>>2)&1
        in_2=(rep>>1)&1
        in_1=(rep>>0)&1
        set_io(dut,"trigger",in_3);
        set_io(dut,"mosi",in_2);
        set_io(dut,"spi_clk",in_1);
        await asic_sleep(dut,1)
        print_in_out_state(dut)
        assert get_io(dut,"asic_out_2")==in_3
        assert get_io(dut,"asic_out_1")==in_2
        assert get_io(dut,"asic_out_0")==in_1
        
    

def print_in_out_state(dut,is_header=False):
    if(is_header):
        dut._log.info(" II II II II OO OO OO OO")
        dut._log.info(" 76 54 32 10 76 54 32 10")
        return
    line="|"
    for is_out in [False,True]:
        value=dut.uo_out.value if is_out else dut.ui_in.value
        index_list=list(range(8))#MSbit on left, LSbit on right
        index_list.reverse()
        for idx in index_list:
            if(get_bit(value,idx)): line+="."
            else: line+=" "
            if(idx%2==0): line+="|"
    #line+=str(get_io(dut,"asic_out_0"))
    dut._log.info(line)

#index 0 is MSbit, 7 is LSbit
def get_bit(value,index):
    #return (value >> (7-index)) & 1
    return (value >> index) & 1

async def set_print_charlie(dut,frame_index,is_mirror):
    await exchange_spi_byte(dut,19,frame_index|(is_mirror<<2),1)
    charlie=await get_charlie(dut)
    dut._log.info("Frame %d:"%frame_index)
    print_charlie(dut,charlie,is_mirror)

async def get_charlie(dut):
    out=[[0 for col in range(8)] for row in range(8)]
    for iter in range(64):
        await asic_sleep(dut,1)#await ClockCycles(dut.clk, 1)
        row=get_charlie_bi_en_bit(dut,1)
        col=get_charlie_bi_en_bit(dut,0)
        if(not row==col and row>=0 and col>=0):
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
    if(is_mirror): dut._log.info(" 01234567 ")
    else: dut._log.info(" 76543210 ")
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
    if(is_mirror): dut._log.info(" 01234567 ")
    else: dut._log.info(" 76543210 ")

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
        index_order=list(range(8))
        index_order.reverse()
        for iter in index_order:#send MSbit first
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
        case "trigger":     index=3
        case "asic_in_0":   index=4
        case "asic_in_1":   index=5
        case "asic_in_2":   index=6
        case "asic_in_3":   index=7
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
        case "asic_out_0": index=0
        case "asic_out_1": index=1
        case "asic_out_2": index=2
        case "asic_out_3": index=3
        case "asic_out_4": index=4
        case "asic_out_5": index=5
        case "asic_out_6": index=6
        case "miso":  index=7
        case _: raise ValueError("DUT IO name not found: "+name)
    return (dut.uo_out.value>>index)&0x01
