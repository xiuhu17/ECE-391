// All necessary declarations for the Tux Controller driver must be in this file

#ifndef TUXCTL_H
#define TUXCTL_H

// magic number, the command id, and the data type that will be passed (if any)
#define TUX_SET_LED             _IOR('E', 0x10, unsigned long)
#define TUX_READ_LED            _IOW('E', 0x11, unsigned long*)
#define TUX_BUTTONS             _IOW('E', 0x12, unsigned long*)
#define TUX_INIT                _IO('E', 0x13)
#define TUX_LED_REQUEST         _IO('E', 0x14)
#define TUX_LED_ACK             _IO('E', 0x15)
#define LED_ARG_COUNT           6
#define LED_COUNT               4 
#define UPPER16                 16
#define UPPER24                 24
#define FOUR_BIT                0x0f


#endif

