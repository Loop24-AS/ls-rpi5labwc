#!/bin/bash

# Define variables
THEME_NAME="loopsign"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
SCRIPT_FILE="$THEME_DIR/$THEME_NAME.script"
PLYMOUTH_FILE="$THEME_DIR/$THEME_NAME.plymouth"
SPLASH_IMAGE="/home/loopsign/ls-rpi5labwc/splash.png"

# Create the theme directory
sudo mkdir -p "$THEME_DIR"

# Create the loopsign.plymouth file
sudo bash -c "cat > $PLYMOUTH_FILE << EOL
[Plymouth Theme]
Name=LoopSign theme
Description=A custom Plymouth theme for LoopSign
ModuleName=script

[script]
ImageDir=$THEME_DIR
ScriptFile=$SCRIPT_FILE
EOL"

# Create the loopsign.script file
sudo bash -c "cat > $SCRIPT_FILE << 'EOL'
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

theme_image = Image(\"splash.png\");
image_width = theme_image.GetWidth();
image_height = theme_image.GetHeight();

scale_x = image_width / screen_width;
scale_y = image_height / screen_height;

flag = 1;

if (scale_x > 1 || scale_y > 1)
{
    if (scale_x > scale_y)
    {
        resized_image = theme_image.Scale (screen_width, image_height / scale_x);
        image_x = 0;
        image_y = (screen_height - ((image_height  * screen_width) / image_width)) / 2;
    }
    else
    {
        resized_image = theme_image.Scale (image_width / scale_y, screen_height);
        image_x = (screen_width - ((image_width  * screen_height) / image_height)) / 2;
        image_y = 0;
    }
}
else
{
    resized_image = theme_image.Scale (image_width, image_height);
    image_x = (screen_width - image_width) / 2;
    image_y = (screen_height - image_height) / 2;
}

if (Plymouth.GetMode() != \"shutdown\")
{
    sprite = Sprite (resized_image);
    sprite.SetPosition (image_x, image_y, -100);
}

message_sprite = Sprite();
message_sprite.SetPosition(screen_width * 0.1, screen_height * 0.9, 10000);

fun message_callback (text) {
    my_image = Image.Text(text, 1, 1, 1);
    message_sprite.SetImage(my_image);
    sprite.SetImage (resized_image);
}

Plymouth.SetUpdateStatusFunction(message_callback);
EOL"

# Copy the splash image to the theme directory
sudo cp "$SPLASH_IMAGE" "$THEME_DIR/splash.png"

# Set the new theme as the default and update the initramfs
sudo plymouth-set-default-theme -R "$THEME_NAME"

echo "Plymouth theme '$THEME_NAME' has been successfully installed and applied!"
