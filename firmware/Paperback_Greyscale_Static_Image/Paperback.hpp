#pragma once
#include "Arduino.h"

/* Control Lines */
#define NEG_CTRL  GPIO_NUM_33  // Active HIGH
#define POS_CTRL  GPIO_NUM_25  // Active HIGH
#define SMPS_CTRL GPIO_NUM_26  // Active LOW

/* Control Lines */
#define GMODE     GPIO_NUM_32
#define SPH       GPIO_NUM_12
#define CKV       GPIO_NUM_23
#define SPV       GPIO_NUM_22
#define RL        GPIO_NUM_21
#define SHR       GPIO_NUM_0
#define OE        GPIO_NUM_2

/* Edges */
#define CL        GPIO_NUM_15
#define LE        GPIO_NUM_13

/* Data Lines */
#define D7        GPIO_NUM_19
#define D6        GPIO_NUM_18
#define D5        GPIO_NUM_5
#define D4        GPIO_NUM_27
#define D3        GPIO_NUM_17
#define D2        GPIO_NUM_14
#define D1        GPIO_NUM_16
#define D0        GPIO_NUM_4

class Paperback
{
public:
        /* Paperback constructor.

        Set up the three delays (usually non-delays), and init all of the
        GPIOs we'll need to flip pins on the ePaper display. */
        Paperback(
              uint32_t clock_delay_in,
              uint32_t vclock_delay_in,
              uint32_t output_delay_in
        );
        /*
        Output data to the GPIOs connected to the Data pins of the ePaper
        display.  These will be shifted into pixel positions to be drawn (or
        NOP'd) to the screen
        */
        void data_output(const uint8_t& data);

        /* Convert LIGHT/DARK areas of the image to ePaper write commands */
        uint8_t pixel_to_epd_cmd(const uint8_t& pixel);

        /* Flip the horizontal clock HIGH/LOW */
        void clock_pixel();

        /* After shifting a row, output it to the screen. */
        void output_row();

        /*
        After adding pixels to the row, latch it to the ePaper display's
        latches.
        */
        void latch_row();

        /* Turn on and off the High Voltage +22V/-20V and +15V/-15V rails */
        void poweron();
        void poweroff();

        /* Start and stop the vertical write */
        void vscan_start();
        void vscan_end();

        /* Start and stop a horizontal (one line) write */
        void hscan_start();
        void hscan_end();


private:
        /* Constant delays, from the .ino file */
        uint32_t clock_delay;
        uint32_t vclock_delay;
        uint32_t output_delay;

        /* Initialize the GPIOs we need (using 20) */
        void init_gpios();

        /* 'Normal' speed bit flip */
        void gpio_set_lo(const gpio_num_t& gpio_num);
        void gpio_set_hi(const gpio_num_t& gpio_num);

        /*
        Write bits directly using the registers.  Won't work for some signals
        (>= 32) and too fast for others (such as horizontal clock for the
         latches.  We use it for data.
        */
        void fast_gpio_set_lo(const gpio_num_t& gpio_num);
        void fast_gpio_set_hi(const gpio_num_t& gpio_num);
};
