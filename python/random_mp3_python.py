#!/usr/bin/env python
import os, random, subprocess, time

# squid LED and button
from squid import *
from button import *

# espeak (it'll throw errors but...)
from espeak import espeak

# find a random file to play in dir
def randomMusic( dir ):
	files = [os.path.join(path, filename)
		for path, dirs, files in os.walk(dir)
		for filename in files
		if not filename.endswith(".m4a")]
	return random.choice(files)

# set the volume 
def setMixer( vol ):
	os.popen ('amixer -q set PCM -- -' + str(vol))
	return

# instantiate button and LED objects
rgb = Squid(18, 23, 24)
button = Button(25)

# this is where the magic happens - putting it in a function so I can execute it multiple times...
def playMusic():
	# change volume to a happy level
	vol=2200
	setMixer(vol)

	# grab a random file
	file = randomMusic('/home/pi/music')

	# kick off mpg123 in background
	p = subprocess.Popen(['mpg123', '-q', file])
	pid = p.pid

	# if this displays WHILE the music is playing, it's doing the right thing
	print "Debug: Playing " + file + ' (pid ' + str(pid) + '), please wait...'

	# we can't crank the volume too high or the wife will be mad...
	volLimit=800
	color="RED"
	counter=0
	buttonCount=0

	while True:
		if color == "RED":
			rgb.set_color(RED, 100)
			color="GREEN"
		elif color == "GREEN":
			rgb.set_color(GREEN, 100)
			color="BLUE"
		elif color == "BLUE":
			rgb.set_color(BLUE, 100)
			color="WHITE"
		elif color == "WHITE":
			rgb.set_color(WHITE, 300)
			color="RED"
		if vol > volLimit and counter > 10:
			counter=0
			vol = vol - 10
			setMixer(vol)
			#print ("Debug: Volume set to " + str(vol))
		if button.is_pressed():
			print "Debug: Button pressed!"
			
			# here we go into a loop waiting for the third button press to stop... or we'll start playing music again very shortly
			p.terminate()
			
			# turn LED off
			rgb.set_color(OFF)
			
			# select a new song in case we don't press the button again 
			file = randomMusic('/home/pi/music')
			
			# we're going to sleep somewhere between 3000 and 6000 milliseconds - 5 to 10 minutes
			sleepTimer = random.randint(3000,6000)
			sleepCounter = 0
			sleepMinutes = (sleepTimer / 10) / 60
			message = "Sleeping for approximately " + str(sleepMinutes) + "minutes"
			print message
			setMixer(800)
			#os.popen("echo " + message + " | festival --tts")
			espeak.synth(message)
			
			while sleepCounter < sleepTimer:
				if button.is_pressed():
					print "Sleep aborted - you pushed the button!"
					p.terminate()
					espeak.synth("snooze has been disabled - time to get up")
					time.sleep(3)
					exit()
				sleepCounter += 1
				time.sleep(0.1)
			
			print "Sleep time is over! Wake up!"
			# we're not going to be nice, you already slept once, cranking the volume 
			setMixer(1000)
			
			# start playing music and wait for someone to push the damn button
			p = subprocess.Popen(['mpg123', '-q', file])
			while p.poll() is None:
				if button.is_pressed():
					p.terminate()
					exit()
				time.sleep(0.1)
			
			# at the end of this if statement - exit
			exit()
		counter += 1
		time.sleep(0.1)

	# if we don't do this the music will keep playing till the song is finished, even after you push the button
	if p.poll() is None:
		p.terminate()

	print "OK, mpg123 should be done now. Or, you pushed the button. Either way."

playMusic()