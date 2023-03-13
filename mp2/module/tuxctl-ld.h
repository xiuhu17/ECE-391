#ifndef TUXCTL_LD_H
#define TUXCTL_LD_H

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/tty.h>

/* tuxctl-ld.h
 * Interface between line discipline and driver */

/* "CURR" <----read----- line-discipline <----receive---- CONTROLLER
 * tuxctl_ldisc_get()
 * Read BYTES that the line-discipline has received from the controller.
 * Returns the number of bytes actually read, or  -1 on error (if, for
 * example, the first argument is invalid.
 * int tuxctl_ldisc_get(struct tty_struct *tty, char *buf, int n)
 */
extern int tuxctl_ldisc_get(struct tty_struct*, char *, int);


/* DEVICE <----write---- "CURR"
 * tuxctl_ldisc_put()
 * Write BYTES out to the device. Returns the number of bytes *not* written.
 * This means, 0 on success and >0 if the line discipline's internal buffer
 * is full.
 */
extern int tuxctl_ldisc_put(struct tty_struct*, char const*, int);

/* tuxctl_handle_packet
 * To be written by the student.  This function will handle a 
 * packet sent to the computer from the tux controller.  This is
 * called by tuxctl_ldisc_data_callback().
 */
void tuxctl_handle_packet(struct tty_struct *tty, unsigned char *packet);


/* ioctl for the line discipline that the students will implement.
 * Located in tuxctl.c
 */
extern int tuxctl_ioctl(struct tty_struct * tty, struct file *, unsigned int cmd, unsigned long arg);


#endif

