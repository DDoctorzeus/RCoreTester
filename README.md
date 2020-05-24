# RCoreTester
A script that tests and measures the boost capacity of each individual core on the system.

Techtonic Software 2020 - http://www.techtonicsoftware.com/

This Program/Script Is Licensed Under GNU V3 (https://www.gnu.org/licenses/gpl-3.0.en.html) and comes with ABSOLUTELY NO WARRANTY. You may distribute, modify and run it however you must not claim it as your own nor sublisence it.

Any distribution must include this readme file.

This script requires the following binaries: 'lscpu' 'grep' 'sed' 'taskset' 'stress' 'bc'.

I created this script in my spare time for my own personal use to help identify which cores on my Ry**n CPU have the best silicon quality and were able to boost the highest. This is useful for identifying the best performing cores for performance tuning with CPU Optomization Software (in my case my own Software RThreader (https://github.com/TechtonicSoftware/RThreader)). While I have tried to accommodate for systems with multiple CPU sockets I havn't tested it extensively on them.

Please note this is a script that performs stress tests on your system using the 'stress' binary. While this is normally completely safe - by using it you do however agree to indemnify me and Techtonic Software of any and all damage that might be caused by its use to your system or otherwise (e.g. overheating CPU, etc).

Usage: ./command args
	none: Operate in default test mode.
    --help: Show this dialog.
    -s: Silent mode - do not show intro, ask to start test and only output results.
    -vc: Virtual Core Mode - Output all results as their virtual core/thread value on the system.
    -csv: CSV Mode - Output final results on one line seperated by commas.