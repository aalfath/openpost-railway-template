#!/bin/sh
# Railway shows the host's CPUs inside a 1 vCPU service, so ffmpeg would start
# one thread per host CPU. Cap decoder and filter threads to the service's CPUs.
n="${OPENPOST_FFMPEG_THREADS:-2}"
exec /usr/bin/ffmpeg -threads "$n" -filter_threads "$n" "$@"
