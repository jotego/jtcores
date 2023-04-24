void arknoid2_state::mcu_reset()
{
    m_mcu_initializing = 3;
    m_mcu_coinage_init = 0;
    m_mcu_coinage[0] = 1;
    m_mcu_coinage[1] = 1;
    m_mcu_coinage[2] = 1;
    m_mcu_coinage[3] = 1;
    m_mcu_coins_a = 0;
    m_mcu_coins_b = 0;
    m_mcu_credits = 0;
    m_mcu_reportcoin = 0;
    m_mcu_command = 0;
}

void arknoid2_state::mcu_handle_coins( int coin )
{
    /* The coin inputs and coin counters are managed by the i8742 mcu. */
    /* Here we simulate it. */
    /* Credits are limited to 9, so more coins should be rejected */
    /* Coin/Play settings must also be taken into consideration */

    if (coin & 0x08)    /* tilt */
        m_mcu_reportcoin = coin;
    else if (coin && coin != m_insertcoin)
    {
        if (coin & 0x01)    /* coin A */
        {
//          logerror("Coin dropped into slot A\n");
            machine().bookkeeping().coin_counter_w(0,1); machine().bookkeeping().coin_counter_w(0,0); /* Count slot A */
            m_mcu_coins_a++;
            if (m_mcu_coins_a >= m_mcu_coinage[0])
            {
                m_mcu_coins_a -= m_mcu_coinage[0];
                m_mcu_credits += m_mcu_coinage[1];
                if (m_mcu_credits >= 9)
                {
                    m_mcu_credits = 9;
                    machine().bookkeeping().coin_lockout_global_w(1); /* Lock all coin slots */
                }
                else
                {
                    machine().bookkeeping().coin_lockout_global_w(0); /* Unlock all coin slots */
                }
            }
        }

        if (coin & 0x02)    /* coin B */
        {
//          logerror("Coin dropped into slot B\n");
            machine().bookkeeping().coin_counter_w(1,1); machine().bookkeeping().coin_counter_w(1,0); /* Count slot B */
            m_mcu_coins_b++;
            if (m_mcu_coins_b >= m_mcu_coinage[2])
            {
                m_mcu_coins_b -= m_mcu_coinage[2];
                m_mcu_credits += m_mcu_coinage[3];
                if (m_mcu_credits >= 9)
                {
                    m_mcu_credits = 9;
                    machine().bookkeeping().coin_lockout_global_w(1); /* Lock all coin slots */
                }
                else
                {
                    machine().bookkeeping().coin_lockout_global_w(0); /* Unlock all coin slots */
                }
            }
        }

        if (coin & 0x04)    /* service */
        {
//          logerror("Coin dropped into service slot C\n");
            m_mcu_credits++;
        }

        m_mcu_reportcoin = coin;
    }
    else
    {
        if (m_mcu_credits < 9)
            machine().bookkeeping().coin_lockout_global_w(0); /* Unlock all coin slots */

        m_mcu_reportcoin = 0;
    }
    m_insertcoin = coin;
}

uint8_t arknoid2_state::mcu_r(offs_t offset)
{
    static const char mcu_startup[] = "\x55\xaa\x5a";

    //logerror("%s: read mcu %04x\n", m_maincpu->pc(), 0xc000 + offset);

    if (offset == 0)
    {
        /* if the mcu has just been reset, return startup code */
        if (m_mcu_initializing)
        {
            m_mcu_initializing--;
            return mcu_startup[2 - m_mcu_initializing];
        }

        switch (m_mcu_command)
        {
            case 0x41:
                return m_mcu_credits;

            case 0xc1:
                /* Read the credit counter or the inputs */
                if (m_mcu_readcredits == 0)
                {
                    m_mcu_readcredits = 1;
                    if (m_mcu_reportcoin & 0x08)
                    {
                        m_mcu_initializing = 3;
                        return 0xee;    /* tilt */
                    }
                    else return m_mcu_credits;
                }
                else return m_in0->read();  /* buttons */

            default:
                logerror("error, unknown mcu command\n");
                /* should not happen */
                return 0xff;
        }
    }
    else
    {
        /*
        status bits:
        0 = mcu is ready to send data (read from c000)
        1 = mcu has read data (from c000)
        2 = unused
        3 = unused
        4-7 = coin code
              0 = nothing
              1,2,3 = coin switch pressed
              e = tilt
        */
        if (m_mcu_reportcoin & 0x08) return 0xe1;   /* tilt */
        if (m_mcu_reportcoin & 0x01) return 0x11;   /* coin 1 (will trigger "coin inserted" sound) */
        if (m_mcu_reportcoin & 0x02) return 0x21;   /* coin 2 (will trigger "coin inserted" sound) */
        if (m_mcu_reportcoin & 0x04) return 0x31;   /* coin 3 (will trigger "coin inserted" sound) */
        return 0x01;
    }
}

void arknoid2_state::mcu_w(offs_t offset, uint8_t data)
{
    if (offset == 0)
    {
        //logerror("%s: write %02x to mcu %04x\n", m_maincpu->pc(), data, 0xc000 + offset);
        if (m_mcu_command == 0x41)
        {
            m_mcu_credits = (m_mcu_credits + data) & 0xff;
        }
    }
    else
    {
        /*
        0xc1: read number of credits, then buttons
        0x54+0x41: add value to number of credits
        0x15: sub 1 credit (when "Continue Play" only)
        0x84: coin 1 lockout (issued only in test mode)
        0x88: coin 2 lockout (issued only in test mode)
        0x80: release coin lockout (issued only in test mode)
        during initialization, a sequence of 4 bytes sets coin/credit settings
        */
        //logerror("%s: write %02x to mcu %04x\n", m_maincpu->pc(), data, 0xc000 + offset);

        if (m_mcu_initializing)
        {
            /* set up coin/credit settings */
            m_mcu_coinage[m_mcu_coinage_init++] = data;
            if (m_mcu_coinage_init == 4)
                m_mcu_coinage_init = 0; /* must not happen */
        }

        if (data == 0xc1)
            m_mcu_readcredits = 0;  /* reset input port number */

        if (data == 0x15)
        {
            m_mcu_credits = (m_mcu_credits - 1) & 0xff;
            if (m_mcu_credits == 0xff)
                m_mcu_credits = 0;
        }
        m_mcu_command = data;
    }
}

INTERRUPT_GEN_MEMBER(arknoid2_state::mcu_interrupt)
{
    int coin = ((m_coin1->read() & 1) << 0);
    coin |= ((m_coin2->read() & 1) << 1);
    coin |= ((m_in2->read() & 3) << 2);
    coin ^= 0x0c;
    mcu_handle_coins(coin);

    device.execute().set_input_line(0, HOLD_LINE);
}

void arknoid2_state::machine_reset()
{
    /* initialize the mcu simulation */
    mcu_reset();

    m_mcu_readcredits = 0;
    m_insertcoin = 0;
}

void arknoid2_state::machine_start()
{
    tnzs_base_state::machine_start();

    save_item(NAME(m_mcu_readcredits));
    save_item(NAME(m_insertcoin));
    save_item(NAME(m_mcu_initializing));
    save_item(NAME(m_mcu_coinage_init));
    save_item(NAME(m_mcu_coinage));
    save_item(NAME(m_mcu_coins_a));
    save_item(NAME(m_mcu_coins_b));
    save_item(NAME(m_mcu_credits));
    save_item(NAME(m_mcu_reportcoin));
    save_item(NAME(m_mcu_command));

    // kludge to make device work with active-high coin inputs
    m_upd4701->left_w(0);
    m_upd4701->middle_w(0);
}

void arknoid2_state::bankswitch1_w(uint8_t data)
{
    tnzs_base_state::bankswitch1_w(data);

    if (BIT(data, 2))
        mcu_reset();

    // never actually written by arknoid2 (though code exists to do it)
    m_upd4701->resetx_w(BIT(data, 5));
    m_upd4701->resety_w(BIT(data, 5));
}
