This is a quick-and-dirty Mac OS X command-line application that registers with the SystemConfiguration framework's notification system to log changes to wireless state.  For example:

    % ./NetworkMonitor
    Starting up NetworkMonitor...
    [15:45:00]  Associated with <AP name> (<AP MAC address>) on channel 11.
    [15:45:30]  Disconnected.
    ^C
    Shutting down...

Tested on OS X 10.8.
