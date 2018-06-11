#!/usr/bin/tclsh
#
# A very simple Tcl script to play music 
#

package require sndfile
package require opusfile
package require mpg123
package require tpulsesimple
package require tcltaglib

set bits 16
set channels 2
set samplerate 44100
set alformat AL_FORMAT_STEREO16
set isMp3 2

if {$argc == 1} {
    set name [lindex $argv 0]
} else {
    puts "Please give the correct argument!"
    exit
}

# Use tcltaglib to get file info
set filehandle [taglib::file_new $name]
if {[taglib::file_is_valid $filehandle] != 0} {
    set audioperp [taglib::audioproperties $filehandle]
    
    set length [lindex $audioperp 0]
    set bitrate [lindex $audioperp 1]
    set samplerate [lindex $audioperp 2]
    set channels [lindex $audioperp 3]
    
    puts "length: $length"
    puts "bitrate: $bitrate"
    puts "samplerate: $samplerate"
    puts "channels: $channels"
    
    set tag [taglib::file_tag $filehandle]
    set title [taglib::tag_title $tag]
    puts "Title: $title"
    
    set artist [taglib::tag_artist $tag]
    puts "Artist: $artist"

    set album [taglib::tag_album $tag]
    puts "Album: $album"

    set year [taglib::tag_year $tag]
    puts "Year: $year"
    
    taglib::tag_free $tag
    taglib::file_free $filehandle
}

# Check file extension
if {[string compare [string tolower [file extension $name]] ".mp3"] != 0} {
    if {[string compare [string tolower [file extension $name]] ".opus"] != 0} {
        if {[catch {set data [sndfile snd0 $name READ]}]} {
            puts "Read file failed."
            exit
        } else {
            set isMp3 0
            set encoding [dict get $data encoding]

            switch $encoding {
                {pcm_16} {
                        set bits 16
                    }
                    {pcm_24} {
                        set bits 24
                    }
                    {pcm_32} {
                        set bits 32
                    }
                    {pcm_s8} {
                        set bits 8
                    }
                    {pcm_u8} {
                        set bits 8
                    }
                    default {
                        set bits 16
                    }
            }

            set channels [dict get $data channels]
            set samplerate [dict get $data samplerate]
            set size [expr [dict get $data frames] * $channels * $bits / 8]
            set buffersize [expr $samplerate * $bits / 8]
            snd0 buffersize $buffersize
            set buffer_number [expr $size / $buffersize + 1]
        }
    } else {
        if {[catch {set data [opusfile opus0 $name]}]} {
            puts "Read file failed."
            exit
        } else {
            set isMp3 1
            set bits [dict get $data bits]
            set channels [dict get $data channels]
            set samplerate [dict get $data samplerate]
            set size [expr [dict get $data length] * $samplerate * $channels * $bits / 8]
            set buffersize [expr $samplerate * $bits / 8]
            opus0 buffersize $buffersize

            # FIXME: opusfile read 960 samples per channel (almost)... not sure
            set buffer_number [expr ($size / (960 * $channels)) + 1]
        }
    }
} else {
        if {[catch {set data [mpg123 mpg0 $name]}]} {
        puts "Read file failed."
        exit
    } else {
        set bits [dict get $data bits]
        set channels [dict get $data channels]
        set samplerate [dict get $data samplerate]
        set size [expr [dict get $data length] * $channels * $bits / 8]
        set buffersize [expr $samplerate * $bits / 8]
        mpg0 buffersize $buffersize
        set buffer_number [expr $size / $buffersize + 1]
    }
}

pulseaudio::simple simple0 -direction PLAYBACK \
  -appname "PlayMP3" \
  -format SAMPLE_S16LE \
  -rate [dict get $data samplerate] \
  -channels [dict get $data channels]

# libao needs use read_short to get data
if {$isMp3==2} {
    while {[catch {set buffer [mpg0 read]}] == 0} {
        simple0 write $buffer
    }
} elseif {$isMp3==1} {
    while {[catch {set buffer [opus0 read]}] == 0} {
        simple0 write $buffer
    }
} else {
    while {[catch {set buffer [snd0 read_short]}] == 0} {
        simple0 write $buffer
    }
}

simple0 close

if {$isMp3==2} {
    mpg0 close
} elseif {$isMp3==1} {
    opus0 close
} else {
    snd0 close
} 
