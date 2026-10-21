[Variables]
; English user interface. Selected with Language=en in Variables.inc.
; To add a language: copy this file as <code>.inc, translate the values (keep the
; %s placeholders) and save it as UTF-16 LE if it contains non-ASCII characters.

; Lists: Sunday first for the weekdays (same order as Lua's os.date wday)
TxtMonths=January,February,March,April,May,June,July,August,September,October,November,December
TxtMonthsShort=Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec
TxtWeekdaysShort=Sun,Mon,Tue,Wed,Thu,Fri,Sat
TxtWeekdayLetters=S,M,T,W,T,F,S

; Static texts in the skin
TxtLabelTitle=Title
TxtLabelDate=Date (dd/mm/yyyy)
TxtLabelStart=Start
TxtLabelEnd=End
TxtChipEvent=Event
TxtRefreshButton=Refresh
TxtCtxRefresh=Refresh now
TxtCtxOpenGoogle=Open Google Calendar
TxtCtxConnect=Connect / reconnect Google account
TxtCtxSettings=Edit settings
TxtTipToday=Back to the current month
TxtTipPrev=Previous month
TxtTipNext=Next month
TxtTipNew=New event or task
TxtTipClose=Close
TxtTipRefresh=Sync calendars and tasks now

; Texts set by GCal.lua (%s = value inserted by the script)
TxtNoTitle=(no title)
TxtTask=Task
TxtAllDay=All day
TxtAllDayOn=%s, all day
TxtUpdatedAt=Updated at %s
TxtLoading=Loading...
TxtSyncing=Syncing...
TxtSaving=Saving...
TxtDeleting=Deleting...
TxtLoginInBrowser=Finish signing in in the browser...
TxtClickHere=%s (click here)
TxtErrorMsg=Error: %s
TxtUnexpected=unexpected response: %s
TxtCannotWriteRequest=Cannot write the request file
TxtMore=+%s more
TxtMoreOpenGoogle=+%s more (open Google Calendar)
TxtNothingPlanned=Nothing planned
TxtNewEventButton=+ Event
TxtNewTaskButton=+ Task
TxtTaskDue=Task - due %s
TxtTaskDueDone=Task - due %s (completed)
TxtBack=Back
TxtClose=Close
TxtConfirmHint=Click "Confirm" again to delete.
TxtConfirm=Confirm
TxtDelete=Delete
TxtMarkDone=Complete
TxtMarkUndone=Mark to do
TxtOpen=Open
TxtNewEvent=New event
TxtNewTask=New task
TxtAddTitle=Add a title
TxtListHint=List (click to change)
TxtCalendarHint=Calendar (click to change)
TxtConnectFirst=Connect Google first
TxtNoneAvailable=None available
TxtSave=Save
TxtCancel=Cancel
TxtBadDate=Invalid date: use dd/mm/yyyy
TxtBadTime=Invalid time: use hh:mm
TxtNeedTitle=Enter a title
TxtConnectAccountFirst=Connect your Google account first
TxtNoCalendar=No calendar available
TxtEndBeforeStart=The end must be after the start
TxtAuthNoClient=Set up Google: see README
TxtAuthNoToken=Not connected to Google
TxtAuthExpired=Google access expired or revoked
