RAINMETER CALENDAR - GOOGLE FOLDER
==================================

Full setup guide (English):  https://github.com/FabioFctrl/FabioFctrl.github.io#readme
Guida completa (italiano):   https://github.com/FabioFctrl/FabioFctrl.github.io/tree/main/it

What goes in this folder:
   client_secret.json  your Google OAuth client ("Desktop app"). You put it here.
                       PRIVATE: never upload it anywhere.
   token.dat           saved sign-in, encrypted with Windows DPAPI (readable only
                       by your Windows user on this PC). Delete it to sign out.
                       Do not copy it to another PC: sign in again there.
   data.tsv            local copy of events and tasks, rewritten at every sync
   request.txt         last request from the widget to the script (temporary)
   last-error.txt      full text of the last error, when the widget shows one

To revoke access: https://myaccount.google.com/permissions
