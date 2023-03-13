/* tuxctl-ioctl.c
 *
 * Driver (skeleton) for the mp2 tuxcontrollers for ECE391 at UIUC.
 *
 * Mark Murphy 2006
 * Andrew Ofisher 2007
 * Steve Lumetta 12-13 Sep 2009
 * Puskar Naha 2013
 */

#include <asm/current.h>
#include <asm/uaccess.h>

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/file.h>
#include <linux/miscdevice.h>
#include <linux/kdev_t.h>
#include <linux/tty.h>
#include <linux/spinlock.h>

#include "tuxctl-ld.h"
#include "tuxctl-ioctl.h"
#include "mtcp.h"

#define debug(str, ...) \
	printk(KERN_DEBUG "%s: " str, __FUNCTION__, ## __VA_ARGS__)

#define low_four 	0x0f
#define RIGHT_UP 	0x09
#define Dn			0x04
#define lE			0x02
#define UP_FOUR		4
#define UP_SIX		3
#define UP_SEVEN	5
#define deci_shift  4
/************************ Protocol Implementation *************************/

/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply 
 * here as well.
 */


/* Each index corropsonding to the bytes value we need to send to the controller*/
/* 					  	0     1     2     3     4     5     6     7     8     9     A     B     C     D     E     F    */
static unsigned char map[16] = {0xE7,0x06,0xCB,0x8F,0x2E,0xAD,0xED,0x86,0xEF,0xAF,0xEE,0x6D,0xE1,0x4F,0xE9,0xE8};
static unsigned int prev_cmd_fin;
static unsigned long button;
static unsigned long prev_led;

int tux_init(struct tty_struct* tty);
int tux_buttons(struct tty_struct* tty, unsigned long* arg);
int tux_set_led(struct tty_struct* tty, unsigned long arg);



/* 
 * tuxctl_handle_packet
 *   DESCRIPTION: Receive the packet from MTC. And we need to either store the packet data 
 * 				  in the globle variable. Or we need to initialize the game
 *   INPUTS: none (ignored)
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: Execute the packet data.
 */
void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet)
{
    unsigned a, b, c, temp, right_up, down, left;

    a = packet[0]; /* Avoid printk() sign extending the 8-bit */
    b = packet[1]; /* values when printing them. */
    c = packet[2];

	switch (a)
	{
	case MTCP_ACK:
		prev_cmd_fin = 1; 	
		break;
	case MTCP_BIOC_EVENT:
		temp = low_four & b;					
		right_up = (RIGHT_UP & c) << UP_FOUR;			
		down = (Dn & c) << UP_SIX;				
		left = (lE & c) << UP_SEVEN;				
		button = right_up | down | left | temp;	
		break;
	case MTCP_RESET:	
		tux_init(tty);
		tux_set_led(tty, prev_led);
		break;
	default:
		return;
	}

	return;

    /*printk("packet : %x %x %x\n", a, b, c); */
}

/******** IMPORTANT NOTE: READ THIS BEFORE IMPLEMENTING THE IOCTLS ************
 *                                                                            *
 * The ioctls should not spend any time waiting for responses to the commands *
 * they send to the controller. The data is sent over the serial line at      *
 * 9600 BAUD. At this rate, a byte takes approximately 1 millisecond to       *
 * transmit; this means that there will be about 9 milliseconds between       *
 * the time you request that the low-level serial driver send the             *
 * 6-byte SET_LEDS packet and the time the 3-byte ACK packet finishes         *
 * arriving. This is far too long a time for a system call to take. The       *
 * ioctls should return immediately with success if their parameters are      *
 * valid.                                                                     *
 *                                                                            *
 ******************************************************************************/
int 
tuxctl_ioctl (struct tty_struct* tty, struct file* file, 
	      unsigned cmd, unsigned long arg)
{	
    switch (cmd) {
	case TUX_INIT:
		return tux_init(tty);
	case TUX_BUTTONS:
		return tux_buttons(tty, (unsigned long*)arg);
	case TUX_SET_LED:
		return tux_set_led(tty, arg);
	case TUX_LED_ACK:								// do not implement
	case TUX_LED_REQUEST:							// do not implement
	case TUX_READ_LED:    							// do not implement
	default:
	    return -EINVAL;
    }
}

/* tux_init
 *   DESCRIPTION: Initialize the tux controller. We need to send two opcode throug put function
 *				  Also need to initilaize the globle variabl
 *   INPUTS: none (ignored)
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: Reset the globle vairbale and reset the tux controller.
 */
int tux_init(struct tty_struct* tty) {
	unsigned int check;
	unsigned char temp[2];
	prev_cmd_fin = 0;
	button = 0xff;
	temp[0] = MTCP_BIOC_ON;
	temp[1] = MTCP_LED_USR;
	check = tuxctl_ldisc_put(tty, temp, 2);
	if (check > 0) return -EINVAL;	
	return 0;
}

/* tux_buttons
 *   DESCRIPTION: Send the data we stoed in the globle variable which is get from 
 *					tuxctl_handle_packet function. We need to use copy_to_usser, since it is kernel mode.
 *   INPUTS: none (ignored)
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: Send data from kernel(we get from controller to kernel through tuxctl_handle_packet) to input.c.
 */
int tux_buttons(struct tty_struct* tty, unsigned long* arg) {
	if (arg == 0x0) {
		return -EINVAL;
	}

	if (0 < copy_to_user((void*)arg, (void*)&button, sizeof(button))) {
		return -EINVAL;
	}

	return 0;
}

/* tux_set_led
 *   DESCRIPTION: Send the data we get from input.c to the tux controller through tuxctl_ldisc_put function.
 *   INPUTS: none (ignored)
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: send data to tux controller.
 */
int tux_set_led(struct tty_struct* tty, unsigned long arg) {
	unsigned char led_send[LED_ARG_COUNT];
	unsigned char set_mode[1];
	unsigned int check, i, count, led_use, decimal_use, value, deci_value;

	if (prev_cmd_fin == 0) return -EINVAL;

	set_mode[0] = MTCP_LED_USR;
	check = tuxctl_ldisc_put(tty, set_mode, 1);
	if (check > 0) return -EINVAL; 

	led_send[0] = MTCP_LED_SET;
	led_send[1] = (arg >> UPPER16) & (FOUR_BIT);	
	led_use = (arg >> UPPER16) & (FOUR_BIT);
	decimal_use =  (arg >> UPPER24) & (FOUR_BIT);

	count = 2;
	for (i = 0; i < LED_COUNT; i ++) {
		if (((led_use >> i) & 0x01) != 0) {
			value = map[(arg >> (i * LED_COUNT)) & FOUR_BIT];
			if ((decimal_use & (1 << i)) != 0) {
				deci_value = 1;
			}else {
				deci_value = 0;
			}
			value = value | (deci_value << deci_shift);
			led_send[count] = value;
			count ++; 
		}
	}

	check = tuxctl_ldisc_put(tty, led_send, count);
	if (check > 0) return -EINVAL; 

	prev_led = arg;
	return 0;
}



