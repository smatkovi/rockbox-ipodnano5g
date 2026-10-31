#include "plugin.h"

enum plugin_status plugin_start(const void *parameter)
{
    (void)parameter;
    rb->lcd_setfont(FONT_SYSFIXED);

    while (true)
    {
        rb->lcd_clear_display();
        rb->lcd_puts(0, 0, "Hold switch status");
        rb->lcd_puts(0, 2, rb->button_hold() ? "LOCKED" : "UNLOCKED");
        rb->lcd_puts(0, 4, "Toggle Hold to update");
        rb->lcd_puts(0, 6, "SELECT exits");
        rb->lcd_update();

        if (rb->button_get_w_tmo(HZ / 10) == BUTTON_SELECT)
            break;
    }

    return PLUGIN_OK;
}
