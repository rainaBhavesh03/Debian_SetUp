#!/usr/bin/env bash

notify-send "Getting list of available Wi-Fi networks..." -t 3000
# Get a list of available wifi connections and morph it into a nice-looking list
wifi_list=$(nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | sed 's/  */ /g' | sed -E "s/WPA*.?\S/ /g" | sed "s/^--/ /g" | sed "s/  //g" | sed "/--/d")

connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
	toggle="󰖪  Disable Wi-Fi"
elif [[ "$connected" =~ "disabled" ]]; then
	toggle="󰖩  Enable Wi-Fi"
fi

# Use rofi to select wifi network
chosen_network=$(echo -e "$toggle\n$wifi_list" | uniq -u | rofi -dmenu -i -selected-row 1 -p "Wi-Fi SSID: " )
# Get name of connection
read -r chosen_id <<< "${chosen_network:3}"

if [ "$chosen_network" = "" ]; then
	exit
elif [ "$chosen_network" = "󰖩  Enable Wi-Fi" ]; then
	nmcli radio wifi on
elif [ "$chosen_network" = "󰖪  Disable Wi-Fi" ]; then
	nmcli radio wifi off
else
	# Define failure messages
	failure_message="Failed to connect to the Wi-Fi network \"$chosen_id\"."
	invalid_psk_message="Invalid PSK. Please try again."
	limit_reached_message="Connection limit reached. Please check the password and try again later."

	# Message to show when connection is activated successfully
  	success_message="You are now connected to the Wi-Fi network \"$chosen_id\"."
	# Get saved connections
	saved_connections=$(nmcli -g NAME connection)

	# Check if chosen_id is in saved connections
	if [[ $(echo "$saved_connections" | grep -w "$chosen_id") = "$chosen_id" ]]; then
	    # Attempt connection with saved settings
	    nmcli connection up id "$chosen_id" | grep "successfully" && {
	        notify-send "Connection Established" "$success_message" -t 3000
	        exit
	    } || {
	        notify-send "$failure_message" -t 3000
	    }
	fi

	# Not in saved connections or connection failed, prompt for password
	max_attempts=3
	attempt_count=0
	# Prompt for password with Rofi textbox and buttons
	while [[ $attempt_count -lt $max_attempts ]]; do
	    wifi_password=$(echo -e "⮠ Back\n❌ Exit" | rofi -dmenu -password -p "Password for $chosen_id: ")
	    
	    if [[ "$wifi_password" = "⮠ Back" ]]; then
	        # User selected "Back", re-run the script
	        exec "$0"  # Use exec to replace the current process
	    elif [[ $wifi_password = "❌ Exit" ]]; then
	            exit
	    fi

	    killall nm-applet
	    # Attempt connection with provided password
	    nmcli device wifi connect "$chosen_id" password "$wifi_password" | grep "successfully" && {
	        notify-send "Connection Established\n" "$success_message" -t 3000
	        exit
	    } || {
	        attempt_count=$((attempt_count + 1))
	        notify-send "$invalid_psk_message" -t 3000
	    }
	done

	# Connection limit reached, clean up and exit
	notify-send "$limit_reached_message" -t 3000
	nmcli connection delete "$chosen_id" 2>/dev/null # Delete if accidentally added
	exit
fi
