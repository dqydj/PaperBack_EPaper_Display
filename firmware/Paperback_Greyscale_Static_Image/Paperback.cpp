#include "Paperback.hpp"

/*
See the header file for comments.  Generally, these are the signals and
orders needed to get the ePaper Display to react to our input.

Others are utility functions to easily write the image to the screen.
*/

Paperback::Paperback(
      uint32_t clock_delay_in,
      uint32_t vclock_delay_in,
      uint32_t output_delay_in
)
      : clock_delay(clock_delay_in)
      , vclock_delay(vclock_delay_in)
      , output_delay(output_delay_in)
{
      init_gpios();
}


void Paperback::init_gpios()
{
        /* Power Control Output/Off */
        pinMode(POS_CTRL, OUTPUT);
        digitalWrite(POS_CTRL, LOW);
        pinMode(NEG_CTRL, OUTPUT);
        digitalWrite(NEG_CTRL, LOW);
        pinMode(SMPS_CTRL, OUTPUT);
        digitalWrite(SMPS_CTRL, HIGH);

        /* Edges/Clocks */
        pinMode(CL, OUTPUT);
        digitalWrite(CL, LOW);
        pinMode(LE, OUTPUT);
        digitalWrite(LE, LOW);

        /* Control Lines */
        pinMode(GMODE, OUTPUT);
        digitalWrite(GMODE, LOW);
        pinMode(SPH, OUTPUT);
        digitalWrite(SPH, LOW);
        pinMode(CKV, OUTPUT);
        digitalWrite(CKV, LOW);
        pinMode(SPV, OUTPUT);
        digitalWrite(SPV, LOW);
        pinMode(RL, OUTPUT);
        digitalWrite(RL, HIGH);
        pinMode(SHR, OUTPUT);
        digitalWrite(SHR, HIGH);
        pinMode(OE, OUTPUT);
        digitalWrite(OE, LOW);

        /* Data Lines */
        pinMode(D7, OUTPUT);
        digitalWrite(D7, LOW);
        pinMode(D6, OUTPUT);
        digitalWrite(D6, LOW);
        pinMode(D5, OUTPUT);
        digitalWrite(D5, LOW);
        pinMode(D4, OUTPUT);
        digitalWrite(D4, LOW);
        pinMode(D3, OUTPUT);
        digitalWrite(D3, LOW);
        pinMode(D2, OUTPUT);
        digitalWrite(D2, LOW);
        pinMode(D1, OUTPUT);
        digitalWrite(D1, LOW);
        pinMode(D0, OUTPUT);
        digitalWrite(D0, LOW);
}


void Paperback::output_row()
{
        // OUTPUTROW
        delayMicroseconds(output_delay);
        gpio_set_hi(OE);
        gpio_set_hi(CKV);
        delayMicroseconds(output_delay);
        gpio_set_lo(CKV);
        delayMicroseconds(output_delay);
        gpio_set_lo(OE);
        // END OUTPUTROW

        // NEXTROW START
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CKV);
        // END NEXTROW
}


void Paperback::latch_row()
{
        gpio_set_hi(LE);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);

        gpio_set_lo(LE);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
}


void Paperback::poweron()
{
        // POWERON
        gpio_set_lo(SMPS_CTRL);
        delayMicroseconds(50);
        gpio_set_hi(NEG_CTRL);
        delayMicroseconds(500);
        gpio_set_hi(POS_CTRL);
        delayMicroseconds(10);
        gpio_set_hi(SPV);
        gpio_set_hi(SPH);
        // END POWERON
}


void Paperback::vscan_start()
{
        // VSCANSTART
        gpio_set_hi(GMODE);
        //gpio_set_hi(OE);
        delayMicroseconds(500);

        gpio_set_hi(SPV);
        delayMicroseconds(vclock_delay);
        gpio_set_lo(CKV);
        delayMicroseconds(vclock_delay);
        gpio_set_hi(CKV);
        delayMicroseconds(vclock_delay);

        gpio_set_lo(SPV);
        delayMicroseconds(vclock_delay);
        gpio_set_lo(CKV);
        delayMicroseconds(vclock_delay);
        gpio_set_hi(CKV);
        delayMicroseconds(vclock_delay);

        gpio_set_hi(SPV);
        delayMicroseconds(vclock_delay);
        gpio_set_lo(CKV);
        delayMicroseconds(vclock_delay);
        gpio_set_hi(CKV);
        delayMicroseconds(vclock_delay);
        // END VSCANSTART
}


void Paperback::vscan_end()
{
        // VSCANEND
        data_output(0B11111111);
        hscan_start();
        for (int j = 0; j < 200; ++j) {
                gpio_set_hi(CL);
                //delayMicroseconds(clock_delay);
                gpio_set_lo(CL);
                //delayMicroseconds(clock_delay);
        }
        hscan_end();
        noInterrupts();
        gpio_set_hi(OE);
        gpio_set_hi(CKV);
        delayMicroseconds(1);
        gpio_set_lo(CKV);
        delayMicroseconds(1);
        gpio_set_lo(OE);
        interrupts();
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        delayMicroseconds(1);
        gpio_set_lo(CKV);
        gpio_set_lo(OE);
        delayMicroseconds(150);
        gpio_set_hi(CKV);
        delayMicroseconds(200);
        gpio_set_lo(CKV);
        delayMicroseconds(1);
        gpio_set_lo(GMODE);
        delayMicroseconds(1);
        // END VSCANEND
}


void Paperback::hscan_start()
{
        // HSCANSTART
        gpio_set_hi(OE);
        gpio_set_lo(SPH);
        // END HSCANSTART
}


void Paperback::hscan_end()
{
        // HSCANEND
        gpio_set_hi(SPH);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
        gpio_set_hi(CL);
        delayMicroseconds(clock_delay);
        gpio_set_lo(CL);
        delayMicroseconds(clock_delay);
}


void Paperback::poweroff()
{
        // POWEROFF
        gpio_set_lo(POS_CTRL);
        delayMicroseconds(10);
        gpio_set_lo(NEG_CTRL);
        delayMicroseconds(100);
        gpio_set_hi(SMPS_CTRL);
        // END POWEROFF
}


void Paperback::clock_pixel()
{
        gpio_set_hi(CL);
        //delayMicroseconds(1);
        gpio_set_lo(CL);
        //delayMicroseconds(1);
}


void Paperback::gpio_set_hi(const gpio_num_t& gpio_num)
{
        digitalWrite(gpio_num, HIGH);
}


void Paperback::gpio_set_lo(const gpio_num_t& gpio_num)
{
        digitalWrite(gpio_num, LOW);
}


void Paperback::fast_gpio_set_hi(const gpio_num_t& gpio_num)
{
        GPIO.out_w1ts = (1 << gpio_num);
}


void Paperback::fast_gpio_set_lo(const gpio_num_t& gpio_num)
{
        GPIO.out_w1tc = (1 << gpio_num);
}


void Paperback::data_output(const uint8_t& data)
{
        (data>>7 & 1 == 1) ? fast_gpio_set_hi(D7) : fast_gpio_set_lo(D7);
        (data>>6 & 1 == 1) ? fast_gpio_set_hi(D6) : fast_gpio_set_lo(D6);
        (data>>5 & 1 == 1) ? fast_gpio_set_hi(D5) : fast_gpio_set_lo(D5);
        (data>>4 & 1 == 1) ? fast_gpio_set_hi(D4) : fast_gpio_set_lo(D4);
        (data>>3 & 1 == 1) ? fast_gpio_set_hi(D3) : fast_gpio_set_lo(D3);
        (data>>2 & 1 == 1) ? fast_gpio_set_hi(D2) : fast_gpio_set_lo(D2);
        (data>>1 & 1 == 1) ? fast_gpio_set_hi(D1) : fast_gpio_set_lo(D1);
        (data>>0 & 1 == 1) ? fast_gpio_set_hi(D0) : fast_gpio_set_lo(D0);
}


uint8_t Paperback::pixel_to_epd_cmd(const uint8_t& pixel)
{
        switch (pixel) {
                case 1:
                        return 0B00000011;
                case 0:
                        return 0B00000001;
                default:
                        return 0B00000011;
        }
}
