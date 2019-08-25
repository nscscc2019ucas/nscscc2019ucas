/**********************************************************************************************************************************************************************
	This file enables the Infrare receiver to receive signals.
**********************************************************************************************************************************************************************/

#include "../config.h"

#if INFRARE_MODULE
void Infrare()
{    
    if((main_flag & wait_8sec)==0){
        if(main_flag & infrare_flag)   //红外处于打开状态
        {            
	    PMU_GPIO_O &= 0xfffffff7;  //IR_PWR OFF
	    //rUart1_MCR &= ~0xa0;  	//MCR bit7:  靠靠;  bit6:Rx靠  bit5:Tx靠靠
            main_flag &= ~infrare_flag;
        }
        else    //红外处于关闭状态
        {       
            main_flag |= infrare_flag;
	    PMU_GPIO_OE |= 1 << 3;  //靠靠IO 靠
	    PMU_GPIO_O |= 1 << 3;  //IR 靠
            RX_IndexW = 0;
#if UART1_INT
	    Uart1_IER  |= 0x1;    //enable uart1 rx int
#endif
    
            wait[1] = 0;
            main_flag |= wait_8sec; 
        }
    }
}

#endif
