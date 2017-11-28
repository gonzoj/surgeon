#!/bin/bash

write_batch()
{
	i=$1
	echo "set *(char *) $i = 's'" > inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'n'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'o'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'o'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'g'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'a'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'n'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 's'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = '.'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 's'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 'o'" >> inject.b
	i=`echo 16o$(($i + 0x1))p | dc | sed -e 's/^/0x/'`
	echo "set *(char *) $i = 0" >> inject.b
	echo "call $dlopen ($preloader, 0x80000001)" >> inject.b
}

open=`ps -e | grep Game.exe | wc -l`
if [ $open -gt 0 ]; then
	pid=`ps -e | grep -m 1 Game.exe | sed -e 's/^ *//' -e 's/^\([0-9][0-9]*\) .*/\1/'`
	if [ -n $pid ]; then
		preloader=`cat /proc/$pid/maps | grep -m 1 preloader | sed -e 's/^\([0-9a-f][0-9a-f]*\)-.*$/0x\1/'`
		libc=`cat /proc/$pid/maps | grep -m 1 libc- | sed -e 's/^\([0-9a-f][0-9a-f]*\)-.*$/0x\1/'`
		libc_path=`cat /proc/$pid/maps | grep -m 1 libc- | sed -e 's/^.* \(\/.*\)$/\1/'`
		game=`cat /proc/$pid/maps | grep -m 1 Game.exe | sed -e 's/^.* \(\/.*\)$/\1/'`
	else
		echo "err: failed to extract PID"
		exit 1
	fi
	if [ -n $libc_path ]; then
		dlopen_offset=`readelf -s $libc_path | grep __libc_dlopen_mode@@GLIBC_PRIVATE | sed -e 's/^.*: \([0-9a-f][0-9a-f]*\) .*$/0x\1/'`
	else
		echo "err: failed to extract path to libc"
		exit 1
	fi
	if [ -n $libc ] & [ -n $dlopen_offset ]; then
		dlopen=`echo 16o$(($libc + $dlopen_offset))p | dc | sed -e 's/^/0x/'`
	else
		echo "err: failed to extract address of libc / offset for __libc_dlopen_mode"
		exit 1
	fi	
	if [ -n $preloader ] & [ -n "$game" ]; then
		write_batch $preloader
		echo "injecting snoogans into process $pid"
		gdb -batch -x inject.b "$game" $pid 1> /dev/null
		rm inject.b
		if [ $? -eq 0 ]; then
			echo "successfully injected"
		else
			echo "err: failed to inject"
		fi
	else
		echo "err: failed to extract path to Game.exe"
		exit 1
	fi
else
	echo "err: couldn't find Game.exe"
fi
