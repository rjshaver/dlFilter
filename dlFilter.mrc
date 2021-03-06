/*
DLFILTER -=- Firewall, anti-spam for mIRC
and message filter for file sharing channels.
Authors: DukeLupus and Sophist

Annoyed by advertising messages from the various file serving bots? Fed up with endless channel messages from other users searching for and requesting files? Are the responses to your own requests getting lost in the crowd?

This script filters out the crud, leaving only the useful messages displayed in the channel. By default, the filtered messages are thrown away, but you can direct them to custom windows if you wish. Functions include:

• For file sharing channels, filter other peoples messages, server adverts and spam
• Collect @find results from file sharing channels into a custom window
• Protect your computer from DCC Sends from other users, except those you have explicitly requested - files you have explicitly requested are accepted automatically
• Limit private messages of all types from other users
• If you are a channel op, provide a separate chat window for operators

This version is a significant upgrade from the previous major release 1.16 with significant new functionality, which we hope will encourage strong take-up.

Feedback on this new version is appreciated. dlFilter is now also an Open Source project, hosted on Github, and we welcome contributions of bug fixes and further improvement from the community.

To load: use /load -rs dlFilter.mrc

Note that dlFilter loads itself automatically as a first script (or second if you are also running sbClient). This avoids problems where other scripts halt events preventing this scripts events from running.

Roadmap
=======
• Improve the ability of users to report issues (e.g. channel messages handled incorrectly) directly from dlFilter popup menus via GitReports.
• Option to filter trivia-games channel messages.
• Integrate sbClient functionality and rename to sbFilter.

Acknowledgements
================
dlFilter uses the following code from other people:

• GetFileName originally based on code from TipiTunes' OS-Quicksearch
• automatic version check based originally on code developed for dlFilter by TipiTunes
• Support for AG6 & 7 by TipiTunes
• Some of the spam definitions are from HugHug's SoftSnow filter.
• Vadi wrote special function to vPowerGet dll that allows sending files from DLF.@find.Results window to vPowerGet.
*/

/* CHANGE LOG

  Immediate TODO
        Test location and filename for oNotice log files
        Test window highlighting (flashing etc.) - define rules.
        Remove Filter wrap lines options and switch to listbox and add right click functions to generate gitreports for false positive filters (with summary of filter settings).
        Create pop-up box option for channels to allow people to cut and paste a line which should be filtered but isn't and create a gitreports call.

  Ideas for possible future enhancements
        Implement toolbar functionality with right click menu
        Check mIRC security settings not too lax
        Manage filetype ignore list like trust list i.e. temp add for requested filetypes.
        Advertising for sbClient for @search + option (await sbClient remediation).
        Better icon file
        Right click channel line menu-items for adding to custom filter (if possible since not a list window)
        More menu options equivalent to dialog options
        Make it work on AdiIRC and update version check handle AdiIRC.
        Merge in sbClient functionality
        Trim lines from Ads window for servers which have been offline for xx hours.
        Configurable F1 etc. aliases to toggle Options, Ads, Filters, Catch-all by F key or other keys.
          (Use On Keydown to capture and check keystrokes, have a key field for each of the options to toggle.)
        Add right click menu items to @find windows to re-sort list by trigger and filename.
        Request and store searchbot triggers to determine @search command validity

*/

alias -l DLF.SetVersion {
  %DLF.version = 1.18
  return %DLF.version
}

alias -l DLF.mIRCversion {
  var %app $nopath($mircexe)
  ; AdiIRC - not sure what version is specifically needed
  ; 2.8 is the version at the time of starting to think about AdiIRC support.
  if ($left(%app,6) == AdiIRC) {
    if ($version >= 2.8) return 0
    %DLF.enabled = 0
    return AidIRC 2.8
  }
  ; mirc - We need returnex first implemented in 6.17
  ; mirc - We need regex /F first implemented in 7.44
  elseif ($version >= 7.44) return 0
  %DLF.enabled = 0
  return mIRC 7.44
}

; ========== Initialisation / Termination ==========
on *:start: {
  ; Reload script if needed to be first to execute
  DLF.LoadCheck .reload
  if (%DLF.JustLoaded) return
  DLF.Initialise
  return

  :error
  DLF.Error During start: $qt($error)
}

on *:load: {
  ; Reload script if needed to be first to execute
  DLF.LoadCheck .load

  set -u1 %DLF.JustLoaded 1
  set -u1 %DLF.OptionInit $false
  DLF.Initialise
  if (%DLF.OptionInit != $false) DLF.Options.Show
  DLF.StatusAll Loading complete.
  return

  :error
  DLF.Error During load: $qt($error)
}

alias -l DLF.LoadCheck {
  if (sbClient.* iswm $nopath($script(1)) || sbClient.* iswm $nopath($script(2))) var %sbc $true
  else var %sbc $false
  if (($script == $script(1)) && (%sbc == $false)) return
  if (($script == $script(2)) && (%sbc)) return
  if (%sbc) var %rs -rs2
  else var %rs -rs1
  $1 %rs $qt($script)
}

alias -l DLF.RenameVar {
  if ($($+(%,DLF.,$2),2) == $null) return
  .set $($+(%,DLF.,$1),1) $($+(%,DLF.,$2),2)
  .unset $($+(%,DLF.,$2),1)
}

on *:signal:DLF.Initialise: { DLF.Initialise $1- }
alias DLF.Initialise {
  ; Handle obsolete variables
  .unset %DLF.custom.selected
  .unset %DLF.filtered.limit
  .unset %DLF.newreleases
  .unset %DLF.ptext
  .unset %DLF.server.limit
  .unset %DLF.showstatus
  ; Make variables more consistent
  if (%DLF.netchans == $null) %DLF.netchans = %DLF.channels
  DLF.RenameVar dccsend.dangerous askregfile.type
  DLF.RenameVar dccsend.nocomchan nocomchan.dcc
  DLF.RenameVar dccsend.untrusted askregfile
  DLF.RenameVar filter.ads ads
  DLF.RenameVar filter.aways away
  DLF.RenameVar filter.joins joins
  DLF.RenameVar filter.kicks kicks
  DLF.RenameVar filter.modeschan chmode
  DLF.RenameVar filter.modesuser usrmode
  DLF.RenameVar filter.nicks nicks
  DLF.RenameVar filter.parts parts
  DLF.RenameVar filter.quits quits
  DLF.RenameVar filter.requests requests
  DLF.RenameVar filter.spamchan chspam
  DLF.RenameVar filter.spampriv privspam
  DLF.RenameVar opwarning.spamchan chspam.opnotify
  DLF.RenameVar opwarning.spampriv privspam.opnotify
  DLF.RenameVar private.nocomchan nocomchan
  DLF.RenameVar private.regular noregmsg
  DLF.RenameVar private.requests privrequests
  DLF.RenameVar serverwin server
  DLF.RenameVar update.betas betas
  DLF.RenameVar win-filter.log filtered.log
  DLF.RenameVar win-filter.strip filtered.strip
  DLF.RenameVar win-filter.timestamp filtered.timestamp
  DLF.RenameVar win-filter.wrap filtered.wrap
  DLF.RenameVar win-onotice.enabled o.enabled
  DLF.RenameVar win-onotice.log o.log
  DLF.RenameVar win-onotice.timestamp o.timestamp
  DLF.RenameVar win-server.log server.log
  DLF.RenameVar win-server.strip server.strip
  DLF.RenameVar win-server.timestamp server.timestamp
  DLF.RenameVar win-server.wrap server.wrap

  if ($script(onotice.mrc)) .unload -rs onotice.mrc
  if ($script(onotice.txt)) .unload -rs onotice.txt
  if (%DLF.JustLoaded) var %init Loading
  else var %init Starting
  DLF.StatusAll %init $c(4,version $DLF.SetVersion) by DukeLupus & Sophist.
  DLF.StatusAll Please check dlFilter homepage $br($c(12,9,$u(https://github.com/DukeLupus/dlFilter/issues))) for help.
  ;DLF.CreateGif
  hfree -w DLF.*
  DLF.CreateHashTables
  DLF.Options.Initialise
  DLF.Groups.Events
  DLF.Ops.AdvertsEnable
  var %ver $DLF.mIRCversion
  if (%ver != 0) DLF.Error dlFilter requires %ver $+ +. dlFilter disabled until mIRC is updated.
}

on *:unload: {
  DLF.Watch.Unload
  var %keepvars $?!="Do you want to keep your dlFilter configuration?"
  DLF.StatusAll Unloading $c(4,9,version $DLF.SetVersion) by DukeLupus & Sophist.
  if (%keepvars == $false) {
    DLF.StatusAll Unsetting variables..
    .unset %DLF.*
  }
  DLF.StatusAll Closing open dlFilter windows
  if ($dialog(DLF.Options.GUI)) .dialog -x DLF.Options.GUI DLF.Options.GUI
  close -a@ @dlF.Filter.*
  close -a@ @dlF.FilterSearch.*
  close -a@ @dlF.Server.*
  close -a@ @dlF.ServerSearch.*
  close -a@ @dlF.@find.*
  close -a@ @dlF.Ads.*
  close -a@ @#*
  DLF.StatusAll Unloading complete.
  DLF.StatusAll $space
  DLF.StatusAll To reload run /load -rs1 $qt($script)
  DLF.StatusAll $space
}

; ========== Main popup menus ==========
menu menubar {
  dlFilter
  .$iif(%DLF.filter.controlcodes,Don't filter,Filter) coloured messages: DLF.Options.ToggleOption filter.controlcodes 345
  .$iif(%DLF.showfiltered,Hide,Show) filter window(s): DLF.Options.ToggleShowFilter
  .$iif(%DLF.serverads,Hide,Show) ads window(s): DLF.Options.ToggleShowAds
  .Options: DLF.Options.Show
  .Visit filter website: .url -a https://github.com/DukeLupus/dlFilter/
  .-
  .Unload dlFilter: if ($?!="Do you want to unload dlFilter?" == $true) .unload -rs $qt($script)
}

menu status {
  dlFilter
  .$iif(%DLF.filter.controlcodes,Don't filter,Filter) coloured messages: DLF.Options.ToggleOption filter.controlcodes 345
  .$iif(%DLF.showfiltered,Hide,Show) filter window(s): DLF.Options.ToggleShowFilter
  .$iif(%DLF.serverads,Hide,Show) ads window(s): DLF.Options.ToggleShowAds
  .Options: DLF.Options.Show
}

menu channel {
  -
  $iif((%DLF.win-onotice.enabled) && ($me isop $chan),Open oNotice chat window) : DLF.oNotice.Open
  -
  dlFilter
  .$iif($DLF.Chan.IsDlfChan($chan,$false),Remove this channel from,Add this channel to) filtering: DLF.Chan.AddRemove
  .Filter all channels currently joined on $network : DLF.Chan.AddJoinedNetwork
  .$iif($scon(0) > 1,Filter all currently joined channels) : DLF.Chan.AddJoinedAll
  .$iif(%DLF.netchans == $hashtag,$style(3)) Filter all channels you join : {
    DLF.Chan.Set $hashtag
    DLF.StatusAll $c(6,Channels set to $c(4,$hashtag))
  }
  .-
  .$iif(%DLF.filter.controlcodes,Don't filter,Filter) coloured messages: DLF.Options.ToggleOption filter.controlcodes 345
  .$iif(%DLF.showfiltered,Hide,Show) filter window(s): DLF.Options.ToggleShowFilter
  .$iif(%DLF.serverads,Hide,Show) ads window(s): DLF.Options.ToggleShowAds
  .Options: DLF.Options.Show
}

; ============================== Event catching ==============================
; ========= Always events ==========
ctcp ^*:VERSION*:#: {
  if (($nick isop $chan) && ($DLF.Chan.IsDlfChan($chan))) DLF.Priv.ctcpreplyVersion
  elseif (%DLF.enabled) DLF.Chan.ctcpBlock $1-
}

ctcp ^*:VERSION*:?: {
  if (($query($nick)) || ($chat($nick,0)) || ($comchan($nick,0) > 0)) DLF.Priv.ctcpreplyVersion
  elseif (%DLF.enabled) DLF.Priv.ctcpBlock $1-
}

on *:close:Status Window: { DLF.Win.CloseServer }
on *:close:@#*: { DLF.oNotice.Close $target }

; Send SNOTICES always to Status
on ^*:snotice:*: {
  echo -stc Notice $+(-,$nick,-) $1-
  halt
}


; ========= Events when dlFilter is enabled ==========
#dlf_events off

; Channel user activity
; join, part, quit, nick changes, kick
on ^*:join:#: {
  var %txt, %joins, %joined
  if ($1-) %txt = : $1-
  if ($shortjoinsparts) %joins = Joins:
  else %joined = has joined $chan $+ %txt
  DLF.Event.Join %joins $nick $br($address) %joined %txt
}
on me:*:join:#: { DLF.Event.MeJoin $1- }
raw 366:*: { DLF.Event.MeJoinComplete $1- }
on ^*:part:#: {
  var %txt, %parts, %hasleft
  if ($1-) %txt = $br($1-)
  if ($shortjoinsparts) %parts = Parts:
  else %hasleft = has left $chan %txt
  DLF.Event.Part %parts $nick $br($address) %hasleft %txt
}
on me:*:part:#: { DLF.Event.MePart $1- }
on ^*:kick:#: {
  var %txt, %addr, %fromchan
  if ($1-) var %txt $br($1-)
  if ($shortjoinsparts) %addr = $br($address($knick,5))
  else %fromchan = from $chan
  DLF.Event.Kick $knick %addr was kicked %fromchan by $nick %txt
}
on ^*:nick: {
  var %addr
  if (!$shortjoinsparts) %addr = $br($address($nick,5))
  DLF.Event.Nick $nick %addr is now known as $newnick
}
on ^*:quit: {
  var %txt, %quits, %quit
  if ($1-) var %txt $br($1-)
  if ($shortjoinsparts) %quits = Quits:
  else %quit = quit
  DLF.Event.Quit $nick %quits $nick $br($address) %quit %txt
}
on me:*:quit: { DLF.Event.MeQuit $1- }
on *:connect: { DLF.Event.MeConnect $1- }
on *:disconnect: { DLF.Event.MeDisconnect $1- }

; User mode changes
; ban, unban, op, deop, voice, devoice etc.
on ^*:ban:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$bnick)) DLF.Chan.Mode $1- }
on ^*:unban:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$bnick)) DLF.Chan.Mode $1- }

on ^*:op:%DLF.channels: {
  if ($opnick != $me) DLF.oNotice.AddNick
  else DLF.oNotice.AddChanNicks
  if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$opnick)) DLF.Chan.Mode $1-
}

on ^*:deop:%DLF.channels: {
  DLF.oNotice.DelNick
  if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$opnick)) DLF.Chan.Mode $1-
}

on ^*:owner:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$opnick)) DLF.Chan.Mode $1- }
on ^*:deowner:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$opnick)) DLF.Chan.Mode $1- }
on ^*:voice:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$vnick)) DLF.Chan.Mode $1- }
on ^*:devoice:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$vnick)) DLF.Chan.Mode $1- }
on ^*:serverop:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$opnick)) DLF.Chan.Mode $1- }
on ^*:serverdeop:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$opnick)) DLF.Chan.Mode $1- }
on ^*:servervoice:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$vnick)) DLF.Chan.Mode $1- }
on ^*:serverdevoice:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modesuser,$vnick)) DLF.Chan.Mode $1- }
on ^*:mode:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modeschan)) DLF.Chan.Mode $1- }
on ^*:servermode:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.modeschan)) DLF.Chan.Mode $1- }

; filter topic changes and when joining channel
on ^*:topic:%DLF.channels: { if ($DLF.Chan.IsChanEvent(%DLF.filter.topic)) DLF.Win.Filter $nick changes topic to: $sqt($1-) }
raw 332:*: { if (($DLF.Chan.IsDlfChan($2)) && (%DLF.filter.topic == 1)) DLF.Win.Filter Topic is: $sqt($1-) }
raw 333:*: { if (($DLF.Chan.IsDlfChan($2)) && (%DLF.filter.topic == 1)) DLF.Win.Filter Set by $1 on $asctime($3,ddd mmm dd HH:nn:ss yyyy) }

; Trigger processing
on *:input:%DLF.channels: {
  if ($DLF.Chan.IsDlfChan($chan)) {
    if (($1 == @find) || ($1 == @locator)) DLF.@find.Request $1-
    elseif (($left($1,1) isin !@) && ($len($1) > 1)) DLF.DccSend.Request $1-
  }
}

on *:filercvd:*: DLF.DccSend.FileRcvd $1-
on *:getfail:*: DLF.DccSend.GetFailed $1-

; Channel messages
on ^*:text:*:%DLF.channels: {
  if ($DLF.oNotice.IsoNotice) DLF.oNotice.Channel $1-
  if ($DLF.Chan.IsChanEvent) DLF.Chan.Text $1-
}
on ^*:action:*:%DLF.channels: {
  if ($DLF.oNotice.IsoNotice) DLF.oNotice.Channel $1-
  if ($DLF.Chan.IsChanEvent) DLF.Chan.Action $1-
}
on ^*:notice:*:%DLF.channels: {
  if ($DLF.oNotice.IsoNotice) DLF.oNotice.Channel $1-
  if ($DLF.Chan.IsChanEvent) DLF.Chan.Notice $1-
}
; oNotice events
on ^@*:text:*:#: { if ($DLF.oNotice.IsoNotice) DLF.oNotice.Channel $1- }
on ^@*:action:*:#: { if ($DLF.oNotice.IsoNotice) DLF.oNotice.Channel $1- }
on ^@*:notice:*:#: { if ($DLF.oNotice.IsoNotice) DLF.oNotice.Channel $1- }
on *:input:@#* { DLF.oNotice.Input $1- }

; Private messages
on ^*:text:*$decode*:?: { DLF.Priv.DollarDecode $1- }
on ^*:notice:*$decode*:?: { DLF.Priv.DollarDecode $1- }
on ^*:action:*$decode*:?: { DLF.Priv.DollarDecode $1- }
on ^*:open:?:*$decode*: { DLF.Priv.DollarDecode $1- }

on ^*:text:*:?: { DLF.Priv.Text $1- }
on ^*:notice:DCC CHAT *:?: { DLF.DccChat.ChatNotice $1- }
on ^*:notice:DCC SEND *:?: { DLF.DccSend.SendNotice $1- }
on ^*:notice:*:?: { DLF.Priv.Notice $1- }
on ^*:action:*:?: { DLF.Priv.Action $1- }
on ^*:open:?:*: { DLF.Priv.Text $1- }

; ctcp
ctcp ^*:FINGER*:#: { DLF.Chan.ctcpBlock $1- }
ctcp ^*:TIME*:#: { DLF.Chan.ctcpBlock $1- }
ctcp ^*:PING*:#: { DLF.Chan.ctcpBlock $1- }
ctcp ^*:FINGER*:?: { DLF.Priv.ctcpBlock $1- }
ctcp ^*:TIME*:?: { DLF.Priv.ctcpBlock $1- }
ctcp ^*:PING*:?: { DLF.Priv.ctcpBlock $1- }

ctcp *:DCC CHAT *:?: { DLF.DccChat.Chat $1- }
ctcp *:DCC SEND *:?: { DLF.DccSend.Send $1- }
ctcp *:*:?: { DLF.Priv.ctcp $1- }
ctcp *:*:%DLF.channels: { if ($DLF.Chan.IsChanEvent) DLF.Chan.ctcp $1- }
on *:ctcpreply:VERSION *: {
  if (%DLF.ops.advertpriv) DLF.Ops.VersionReply $1-
  DLF.Priv.ctcpReply $1-
}
on *:ctcpreply:*: { DLF.Priv.ctcpReply $1- }
; We should not need to handle the open event because unwanted dcc chat requests have been halted.
;on ^*:open:=: { DLF.DccChat.Open $1- }

; RPL_iSupport 005 CNOTICE / CPRIVMSG to avoid 439 Target change too frequently message
raw 005:*: { DLF.iSupport.Raw005 $1- }

; Filter away messages
raw 301:*: { DLF.Away.Filter $1- }

; Show "Unknown command" / "No such nick/channel" messages in active window (rather than hidden in status)
raw 401:*: {
  echo -a $2-
  halt
}
raw 421:*: {
  echo -a $2-
  halt
}

; Adjust titlebar on window change
on *:active:*: { DLF.Stats.Active }

; Process Ctrl-C on @find window
on *:keydown:@dlf.@find.*:*: { if ((!$keyrpt) && ($keyval == 3)) DLF.@find.CopyLines }

#dlf_events end

; Following is just in case groups get reset to default...
; Primarily for developers when e.g. script is reloaded on change by authors autoreload script
#dlf_bootstrap on
on *:text:*:*: { DLF.Groups.Bootstrap }
alias -l DLF.Groups.Bootstrap {
  if (%DLF.enabled != $null) DLF.Groups.Events
  .disable #dlf_bootstrap
}
#dlf_bootstrap end

alias -l DLF.Groups.Events {
  DLF.Stats.Titlebar
  if (%DLF.enabled) {
    .enable #dlf_events
    !.events on
    !.raw on
    !.ctcps on
  }
  else .disable #dlf_events
}

; Override /events/raw/ctcp commands if dlF is enabled - without these dlF does not work
alias events { DLF.CommandDisable events $1- }
alias ctcps { DLF.CommandDisable ctcps $1- }
alias raw { DLF.CommandDisable raw $1- }
alias -l DLF.CommandDisable {
  if ((%DLF.enabled) && ($2 == off)) echo -ac Info * / $+ $1 $+ : you cannot turn off $1 whilst dlFilter is enabled.
  elseif ($show) $(! $+ $1-,2)
  else $(!. $+ $1-,2)
}

; ========== Event splitters ==========
alias -l DLF.Event.Join {
  DLF.Watch.Called DLF.Event.Join $1-
  DLF.@find.ColourNick $nick 3
  if ($DLF.Chan.IsChanEvent) {
    DLF.Ads.ColourLines $event $nick $chan
    DLF.DccSend.Rejoin
    ; Wait for 1 sec for user's modes to be applied to avoid checking ops
    if ((%DLF.ops.advertpriv) && ($me isop $chan)) .timer 1 5 .signal DLF.Ops.RequestVersion $nick
    if (%DLF.filter.joins) DLF.User.Channel $1-
  }
}

alias -l DLF.Event.MeJoin {
  DLF.Watch.Called DLF.Event.MeJoin $1-
  if ($DLF.Chan.IsDlfChan($chan)) DLF.Update.Announce
}

alias -l DLF.Event.MeJoinComplete {
  DLF.Watch.Called DLF.Event.MeJoinComplete $1-
  DLF.@find.ColourMe Join $2
  if ($DLF.Chan.IsDlfChan($2)) DLF.Ads.ColourLines Join $1-2
}

alias -l DLF.Event.Part {
  DLF.Watch.Called DLF.Event.Part $1-
  DLF.oNotice.DelNick
  DLF.@find.ColourNick $nick 14
  if ($DLF.Chan.IsChanEvent) {
    DLF.Ads.ColourLines $event $nick $chan
    if (%DLF.filter.parts) DLF.User.Channel $1-
  }
}

alias -l DLF.Event.MePart {
  DLF.Watch.Called DLF.Event.MePart $1-
  DLF.@find.ColourMe $event $chan
  if ($DLF.Chan.IsDlfChan($chan)) DLF.Ads.ColourLines $event $nick $chan
}

alias -l DLF.Event.Kick {
  DLF.Watch.Called DLF.Event.Kick $1-
  DLF.oNotice.DelNick
  DLF.@find.ColourNick $knick 14
  if ($DLF.Chan.IsChanEvent) {
    DLF.Ads.ColourLines $event $knick $chan
    if (%DLF.filter.kicks) DLF.User.Channel $1-
  }
}

alias -l DLF.Event.Nick {
  DLF.Watch.Called DLF.Event.Nick $1-
  DLF.oNotice.NickChg $1-
  DLF.Ops.NickChg
  DLF.Ads.NickChg
  DLF.Win.NickChg
  if ($DLF.Chan.IsUserEvent(%DLF.filter.nicks)) DLF.User.NoChannel $newnick $1-
}

alias -l DLF.Event.Quit {
  DLF.Watch.Called DLF.Event.Quit $1-
  DLF.oNotice.DelNickAllChans
  DLF.@find.ColourNick $nick 14
  if ($DLF.Chan.IsUserEvent) {
    DLF.Ads.ColourLines $event $nick
    if (%DLF.filter.quits) DLF.User.NoChannel $1-
  }
}

alias -l DLF.Event.MeQuit {
  DLF.Watch.Called DLF.Event.MeQuit $1-
  DLF.@find.ColourMe $event
  DLF.Ads.ColourLines $event $nick
}

alias -l DLF.Event.MeConnect {
  DLF.Watch.Called DLF.Event.MeConnect $1-
  set -ez [ [ $+(%,DLF.CONNECT.CID,$cid) ] ] 40
  DLF.Win.CloseServer
  DLF.Update.Check
}

alias -l DLF.Win.CloseServer {
  if (($event == connect) && (%DLF.perconnect == 0)) return
  DLF.Watch.Called DLF.Win.CloseServer
  var %i $window(@DLF.*,0)
  while (%i) {
    var %win $window(@DLF.*,%i)
    if ($window(%win).cid == $cid) {
      if (($event == close) && ($gettok(%win,-1,$asc(.)) == $network)) close -@ %win
      elseif (($event == connect) && ($gettok(%win,-1,$asc(.)) != $network)) close -@ %win
    }
    dec %i
  }
}

alias -l DLF.Event.JustConnected {
  if ($var($+(DLF.CONNECT.CID,$cid),1).value) return $true
  return $false
}

alias -l DLF.Event.MeDisconnect {
  DLF.Watch.Called DLF.Event.MeDisconnect $1-
  DLF.@find.ColourMe $event
  DLF.Ads.ColourLines $event $nick
  DLF.iSupport.Disconnect
}

; ========== Channel events ==========
; Channel user activity
; join, part, kick
alias -l DLF.User.Channel {
  DLF.Watch.Called DLF.User.Channel $nick
  var %log
  if ($nick == $me) %log = Me
  elseif ($me isin $1-) %log = About me
  elseif ($notify($nick)) %log = Notify user
  elseif (($event == kick) && ($notify($knick))) %log = About notify user
  elseif ((%DLF.filter.regular == 1) && ($DLF.IsRegularUser($nick) == $false)) %log = Filtering only regular users
  else DLF.Win.Filter $1-
  DLF.Watch.Log Not filtered: %log
}

; Non-channel user activity
; nick changes, quit
alias -l DLF.User.NoChannel {
  DLF.Watch.Called DLF.User.NoChannel $1
  if ($notify($nick)) {
    DLF.Watch.Log Not filtered: Notify user
    return
  }
  var %dlfchan $false
  if (%DLF.netchans != $hashtag) {
    var %i $comchan($1,0)
    while (%i) {
      var %chan $comchan($1,%i)
      if (($nick == $me) || ($DLF.Chan.IsDlfChan(%chan) == $false)) echo -tc $event %chan * $2-
      else {
        DLF.Stats.Count %chan Total
        %dlfchan = $true
      }
      dec %i
    }
  }
  if (%dlfchan) DLF.Win.Log Filter $event $hashtag $nick $2-
  else DLF.Watch.Log Echoed to all common $network channels
  halt
}

; Channel & User mode changes
; ban, unban, op, deop, voice, devoice etc.
; ban unban voice devoice etc.
alias -l DLF.Chan.Mode {
  DLF.Watch.Called DLF.Chan.Mode
  if ($nick == $me) {
    DLF.Watch.Log Not filtered: Me
    return
  }
  DLF.Win.Log Filter Mode $chan $nick $nick sets mode: $1-
  halt
}

; ========== Channel messages ==========
alias -l DLF.Chan.AddRemove {
  DLF.Watch.Called DLF.Chan.AddRemove $1-
  if (!$DLF.Chan.IsDlfChan($chan,$false)) DLF.Chan.Add $chan $network
  else DLF.Chan.Remove $chan $network
  if ($dialog(DLF.Options.GUI)) DLF.Options.InitChannelList
}

alias -l DLF.Chan.Add {
  DLF.Watch.Called DLF.Chan.Add $1-
  if ($1) var %nc $+($2,$1), %chan $1
  else var %nc $+($network,$chan), %chan $chan
  if ($DLF.Chan.IsDlfChan(%chan,$false)) {
    DLF.Watch.Log AddChan: %chan already filtered.
    return
  }
  if ($chan(%chan)) echo 4 -t %chan $c(1,4,Channel %chan added to dlFilter list)
  %DLF.netchans = $remtok(%DLF.netchans,%chan,0,$asc($comma))
  if (%DLF.netchans != $hashtag) DLF.Chan.Set $addtok(%DLF.netchans,%nc,$asc($comma))
  else DLF.Chan.Set %nc
}

alias -l DLF.Chan.Remove {
  DLF.Watch.Called DLF.Chan.Remove $1-
  if ($1) var %nc $+($2,$1), %chan $1
  else var %nc $+($network,$chan), %chan $chan
  if (!$DLF.Chan.IsDlfChan(%chan),$false) {
    DLF.Watch.Log RemoveChan: %chan already not filtered.
    return
  }
  if ($chan(%chan)) echo 4 -t %chan $c(1,4,Channel %chan removed from dlFilter list)
  if ($istok(%DLF.netchans,%nc,$asc($comma))) DLF.Chan.Set $remtok(%DLF.netchans,%nc,0,$asc($comma))
  else DLF.Chan.Set $remtok(%DLF.netchans,%chan,0,$asc($comma))
}

alias -l DLF.Chan.AddJoinedNetwork {
  DLF.Watch.Called DLF.Chan.AddJoinedNetwork
  var %i $chan(0)
  while (%i) {
    var %chan $chan(%i)
    dec %i
    if ($istok(%chan,%DLF.netchans,$asc($comma))) continue
    if ($istok($network $+ %chan,%DLF.netchans,$asc($comma))) continue
    DLF.Chan.Add %chan $network
  }
}

alias -l DLF.Chan.AddJoinedAll {
  DLF.Watch.Called DLF.Chan.AddJoinedAll
  scon -at1 DLF.Chan.AddJoinedNetwork
}

; Convert network#channel to just #channel for On statements
alias -l DLF.Chan.Set {
  %DLF.netchans = $replace($1-,$space,$comma)
  var %r /[^,#]+(?=#[^,#]*)/gF
  %DLF.channels = $regsubex(%DLF.netchans,%r,$null)
  %DLF.channels = $uniquetok(%DLF.channels,$asc($comma))
}

; Check if channel is set whether it is network#channel or just #channel
alias -l DLF.Chan.IsChanEvent {
  DLF.Watch.Called DLF.Chan.IsChanEvent
  var %log
  if ($DLF.Chan.IsDlfChan($chan) == $false) %log = Not a filtered channel
  elseif ($nick == $me) %log = Me
  elseif ($DLF.Chan.TargetNick($true) == $me) %log = About me
  elseif (($DLF.IsRegularUser($DLF.Chan.TargetNick)) && (%DLF.filter.regular == 1)) %log = Filtering only regular users
  else DLF.Stats.Count $chan Total
  if ($1 == 0) %log = Filtering off for $event
  if (%log == $null) return $true
  DLF.Watch.Log Not filtered: %log
  return $false
}

alias -l DLF.Chan.IsDlfChan {
  if (($2 != $false) && (%DLF.netchans == $hashtag)) return $true
  if ($istok(%DLF.netchans,$1,$asc($comma))) return $true
  if ($istok(%DLF.netchans,$+($network,$1),$asc($comma))) return $true
  return $false
}

alias -l DLF.Chan.IsCommonDlfChan {
  if ($1 == $null) return $false
  var %i $comchan($1,0)
  while (%i) {
    if ($DLF.Chan.IsDlfChan($comchan($1,%i))) return $true
    dec %i
  }
  return $false
}

alias -l DLF.Chan.TargetNick {
  if ($event == nick) return $newnick
  if ($event == kick) return $knick
  if ($event isin ban unban) return $bnick
  if (!$1) return $nick
  if ($event isin op deop serverop serverdeop owner deowner) return $opnick
  if ($event isin voice devoice servervoice serverdevoice) return $vnick
  else return $nick
}

; Check whether non-channel event (quit or nickname) is from a network where we are in a defined channel
alias -l DLF.Chan.IsUserEvent {
  DLF.Watch.Called DLF.Chan.IsUserEvent
  var %nick $DLF.Chan.TargetNick
  var %log
  if ($1 == 0) %log = Filtering off for $event
  elseif ((%DLF.netchans != $hashtag) && (!$DLF.Chan.IsCommonDlfChan(%nick))) %log = $nick not in filtered channel
  elseif ((!$DLF.IsRegularUser(%nick)) && (%DLF.filter.regular == 1)) %log = Filtering only regular users
  elseif (($notify($nick)) || ($notify($DLF.Chan.TargetNick($true)))) %log = Notify user
  if (%log) {
    DLF.Watch.Log Not filtered: %log
    return $false
  }
  DLF.Watch.Log Filtering: $nick in filtered channel
  return $true
}

alias -l DLF.Chan.Text {
  DLF.Watch.Called DLF.Chan.Text
  ; Remove leading and double spaces
  var %txt $DLF.strip($1-)
  if (%txt == $null) {
    DLF.Watch.Log Dropped: Blank line
    DLF.Win.Filter $1-
  }
  if ($hiswm(chantext.dlf,%txt)) {
    ; Someone else is sending channel ads - reset timer to prevent multiple ops flooding the channel
    var %secs $timer(dlf.advert).secs + 30
    set $+(-eu,%secs) [ $+(%,DLF.opsnochanads.,$network,$chan) ] 1
    DLF.Win.Ads $1-
  }
  if (($me isop $chan) && (%DLF.ops.advertpriv == 1)) {
    if (@find * iswm %txt) DLF.Ops.Advert@find $1-
    ;elseif ($left(%txt,7) == @search) DLF.Ops.Advert@search $1-
    ;elseif (($numtok(%txt,$asc($space)) == 1) && ($left(%txt,1) == @) && ($right($gettok(%txt,1,$asc(-)),-1) ison $chan)) DLF.Ops.Advert@search $1-
  }

  DLF.Custom.Filter $1-
  if ($hiswm(chantext.always,%txt)) DLF.Win.Filter $1-
  if ((%DLF.filter.ads == 1) && ($hiswm(chantext.spam,%txt))) DLF.Win.Filter $1-
  if ((%DLF.filter.ads == 1) && ($hiswm(chantext.ads,%txt))) DLF.Win.Ads $1-
  /*if (%DLF.filter.spamchan == 1) {
    ;no channel spam right now
  }
  */
  if ((%DLF.filter.requests == 1) && ($DLF.Chan.IsCmd(%txt))) DLF.Win.Filter $1-
  DLF.Chan.ControlCodes $1-
}

alias -l DLF.Chan.Action {
  DLF.Watch.Called DLF.Chan.Action
  DLF.Custom.Filter $1-
  var %txt $DLF.strip($1-)
  if ((%DLF.filter.ads == 1) && ($hiswm(chanaction.spam,%txt))) DLF.Win.Filter $1-
  if ((%DLF.filter.aways == 1) && ($hiswm(chanaction.away,%txt))) DLF.Win.Filter $1-
  DLF.Chan.ControlCodes $1-
}

alias -l DLF.Chan.Notice {
  DLF.Watch.Called DLF.Chan.Notice
  DLF.Custom.Filter $1-
  var %txt $DLF.strip($1-)
  if ((%DLF.filter.spamchan == 1) && ($hiswm(channotice.spam,%txt))) DLF.Chan.SpamFilter $1-
  DLF.Chan.ControlCodes $1-
  ; Override mIRC default destination and send to channel rather than active/status windows.
  DLF.Win.Echo $event $chan $nick $1-
  halt
}

alias -l DLF.Chan.ctcp {
  DLF.Watch.Called DLF.Chan.ctcp
  DLF.Custom.Filter $1-
  if ($hiswm(chanctcp.spam,$1-)) DLF.Win.Filter $1-
  if ($hiswm(chanctcp.server,$1-)) DLF.Win.Server $1-
  ; Override mIRC default destination and send to channel rather than active/status windows.
  DLF.Win.Echo $event $chan $nick $1-
  halt
}

alias -l DLF.Chan.IsCmd {
  tokenize $asc($space) $1-
  if ($0 == 0) return $true
  ; Handle mistyped !nick, @search or @nick with incorrect/without trigger character
  var %fn $DLF.GetFileName($2-)
  var %cc $left($1,2)
  if (%fn) {
    ; correct format
    if ($left($1,1) == !) return $true
    ; Missed ! on file get
    if ($1 ison $chan) return $true
    ; Mistyped !  on file get
    if ($right($1,-1) ison $chan) return $true
    ; Extra character on file get
    if (($right(%cc,1) == !) && ($right($1,-2) ison $chan)) return $true
  }
  elseif ($0 == 1) {
    ; correct format
    if ($left($1,1) == @) return $true
    ; Missed @ on server list
    if ($1 ison $chan) return $true
    if ($gettok($1,1,$asc(-)) ison $chan) return $true
    ; Mistyped @ on server list
    if ($right($1,-1) ison $chan) return $true
    if ($gettok($right($1,-1),1,$asc(-)) ison $chan) return $true
    ; Extra character on file get
    if (($right(%cc,1) == @) && ($right($1,-2) ison $chan)) return $true
  }
  else {
    ; correct format
    if ($left($1,7) == @search) return $true
    if ($left($1,5) == @find) return $true
    ; Missed @
    if ($1 == find) return $true
    ; @ space find/search
    if (($1 == @) && ($2 == find)) return $true
    if (($1 == @) && ($left($1,6) == search)) return $true
    ; Mistyped @
    if (($mid($1,2,6) == search) && ($right($1,-1) ison $chan)) return $true
    if ($mid($1,2,4) == find) return $true
    ; Extra character on search
    if (($right(%cc,1) == @) && ($mid($1,3,6) == search) && ($right($1,-2) ison $chan)) return $true
    if (($right(%cc,1) == @) && ($mid($1,3,4) == find)) return $true
  }
  if ($hiswm(chantext.mistakes,$1-)) return $true
  return $false
}

alias -l DLF.Chan.ControlCodes {
  DLF.Watch.Called DLF.Chan.ControlCodes
  if ((%DLF.filter.controlcodes == 1) && ($strip($1-) != $1-)) {
    DLF.Watch.Log Filtered: Contains control codes
    DLF.Win.Filter $1-
  }
}

alias -l DLF.Chan.SetNickColour {
  if (%DLF.colornicks == 1) {
    var %c $color(Highlight)
    if ($1) var %nick $1
    else var %nick $nick
    if ($event != signal) DLF.Watch.Called DLF.Chan.SetNickColour %nick
    var %i $comchan(%nick,0)
    while (%i) {
      var %chan $comchan(%nick,%i)
      dec %i
      if ($nick(%chan,%nick).color != %c) cline %c %chan %nick
    }
  }
}

alias -l DLF.Chan.MsgNick {
  var %nick $DLF.Chan.PrefixedNick($1,$2)
  var %colour $DLF.Chan.NickColour($nick($1,$2).pnick)
  if (%colour != $null) %nick = $c(%colour,%nick)
  return %nick
}

alias -l DLF.Chan.NickColour {
  var %cnick $cnick($1)
  if ((%cnick == 0) || ($enablenickcolors == $false)) var %colour $color(Listbox)
  elseif ($cnick(%cnick).method == 2) var %colour $color(Listbox)
  else var %colour $cnick(%cnick).color
  if (%colour == 0) %colour = 1
  return %colour
}

alias -l DLF.Chan.PrefixedNick {
  if (($showmodeprefix) && ($left($1,1) isin $chantypes)) return $nick($1,$2).pnick
  return $2
}

alias -l DLF.Chan.EditSend {
  ; Done with timers to allow messages to be sent before doing the next one.
  DLF.Watch.Called DLF.Chan.EditSend $1-
  var %delta 1
  var %t $+(DLF.editsend.,$network,$1)
  if ($timer(%t)) {
    var %secs $timer(%t).secs
    var %existing $gettok($timer(%t).com,3-,$asc($space))
  }
  else {
    var %secs 0
    var %existing $editbox($1)
  }
  .timer 1 %secs editbox -n $1-
  inc %secs %delta
  [ $+(.timer,%t) ] 1 %secs editbox $1 %existing
}

alias -l DLF.Chan.ctcpBlock {
  if ($nick isop $chan) return
  DLF.Watch.Called DLF.Chan.ctcpBlock Blocked: $1-
  DLF.Win.Echo Blocked $chan $nick Channel ctcp $1 from $nick
  if ($DLF.Chan.IsDlfChan($chan)) {
    DLF.Stats.Count $chan Total
    DLF.Win.Log Filter ctcp $chan $nick $1-
  }
  else DLF.Win.Echo ctcp $chan $nick $1-
  DLF.Halt Channel $1-2 blocked
}

; ========== Private messages ==========
alias -l DLF.Priv.Text {
  DLF.Watch.Called DLF.Priv.Text
  DLF.@find.Response $1-
  DLF.Priv.Request $1-
  if ($DLF.DccSend.IsTrigger) DLF.Win.Server $1-
  DLF.Priv.QueryOpen $1-
  DLF.Custom.Filter $1-
  var %txt $DLF.strip($1-)
  if ((%DLF.filter.spampriv == 1) && ($hiswm(privtext.spam,%txt)) && (!$window($1))) DLF.Priv.SpamFilter $1-
  if ($hiswm(privtext.server,%txt)) DLF.Win.Server $1-
  if ((%DLF.filter.aways == 1) && ($hiswm(privtext.away,%txt))) DLF.Win.Filter $1-
  DLF.Priv.CommonChan $1-
  DLF.Priv.RegularUser Text $1-
  DLF.Win.Echo $event Private $nick $1-
  halt
}

alias -l DLF.Priv.Notice {
  DLF.Watch.Called DLF.Priv.Notice
  DLF.@find.Response $1-
  DLF.Priv.NoticeServices $1-
  if ($DLF.DccSend.IsTrigger) DLF.Win.Server $1-
  DLF.Custom.Filter $1-
  DLF.Priv.QueryOpen $1-
  var %txt $DLF.strip($1-)
  if ($hiswm(privnotice.dnd,%txt)) DLF.Win.Filter $1-
  if ($hiswm(privnotice.server,%txt)) DLF.Win.Server $1-
  DLF.Priv.CommonChan $1-
  DLF.Priv.RegularUser Notice $1-
  DLF.Win.Echo $event Private $nick $1-
  halt
}

alias -l DLF.Priv.NoticeServices {
  if (($nick == ChanServ) && ($left($1,2) == [#) && ($right($1,1) == ])) {
    var %chan $left($right($1,-1),-1)
    DLF.Watch.Called DLF.Priv.NoticeServices Chanserv Notice redirected to %chan
    DLF.Win.Echo Notice %chan $nick $1-
    halt
  }
}

alias -l DLF.Priv.Action {
  DLF.Watch.Called DLF.Priv.Action
  DLF.Priv.QueryOpen $1-
  DLF.Custom.Filter $1-
  DLF.Priv.CommonChan $1-
  DLF.Priv.RegularUser Action $1-
  DLF.Win.Echo $event Private $nick $1-
  halt
}

alias -l DLF.Priv.Request {
  if (%DLF.private.requests == 0) return
  DLF.Watch.Called DLF.Priv.Request
  if ($nick === $me) return
  var %trigger $strip($1)
  var %nicklist @ $+ $me
  var %nickfile ! $+ $me
  if ((%nicklist == %trigger) || (%nickfile == %trigger) || (%nickfile == $gettok($strip($1),1,$asc(-)))) {
    .msg $nick Please $u(do not make requests in private) $+ . All commands need to go to $u(channel).
    .msg $nick If you are running mIRC, you may have to go to $c(2,mIRC options -> Sounds -> Requests) and uncheck $qt($c(3,Send '!nick file' as private message))
    DLF.Watch.Log Blocked: Request made in private rather than in chan
    DLF.Status Blocked: Request made in private from $nick
    DLF.Win.Log Filter Blocked Private $nick Request made in private from $nick
    DLF.Win.Filter $1-
  }
}

alias -l DLF.Priv.SpamFilter {
  if (%DLF.opwarning.spampriv == 0) return
  DLF.Watch.Called DLF.Priv.SpamFilter
  if (%DLF.spam.addignore == 1) [ $+(.timerDLFSpamIgnore,$DLF.TimerAddress) ] 1 0 .signal DLF.Priv.SpamIgnore $nick $1-
  if ($comchan($nick,0)) var %inchan in common channel(s):
  else var %inchan not in common channel:
  DLF.Win.Log Filter Blocked Private $nick Spam from user %inchan $c(4,15,$tag($nick) $br($address($nick,5)) -> $b($1-))
  DLF.Win.Filter $1-
}

on *:signal:DLF.Priv.SpamIgnore: { DLF.Priv.SpamIgnore $1- }
alias -l DLF.Priv.SpamIgnore {
  DLF.Watch.Called DLF.Priv.SpamIgnore
  var %addr $address($1,6)
  var %who $1
  if (%addr) var %who %who $br(%addr)
  else %addr = %who
  var %ignore $input($&
    $+(Spam received from ,%who,.,$crlf,$crlf,Spam: $qt($2-),.,$crlf,$crlf,Add this user to ignore for one hour?),$&
    yq,Add spammer to /ignore?)
  if (%ignore == $true) {
    DLF.Watch.Log Ignoring $1 $br(%addr) on $network
    .ignore on
    ignore -u3600 %addr $network
  }
}

alias -l DLF.Priv.CommonChan {
  if (%DLF.private.nocomchan != 1) return
  DLF.Watch.Called DLF.Priv.CommonChan
  if ($DLF.IsServiceUser($nick)) return
  if ($comchan($nick,0) == 0) {
    DLF.Watch.Log Blocked: Private $event from regular user
    DLF.Status Blocked: Private $event from $nick with no common channel
    DLF.Win.Log Filter Blocked Private $nick Private $event from user with no common channel:
    DLF.Win.Filter $1-
  }
}

alias -l DLF.Priv.QueryOpen {
  if ((%DLF.private.query == 1) && ($query($nick)) && ($event != open)) {
    DLF.Win.Echo $event $nick $nick $1-
    halt
  }
}

alias -l DLF.Priv.DollarDecode {
  DLF.Win.Echo Warning Private $nick Messages containing $b($ $+ decode) are often malicious mIRC virus trying to infect your mIRC, and $nick is likely already infected with it. Please report this to the channel ops.
  DLF.Win.Echo Warning Private $nick $1-
  DLF.Halt Halted: Probable mIRC worm infection attempt.
}

alias -l DLF.Priv.ctcp {
  DLF.Watch.Called DLF.Priv.ctcp
  DLF.Custom.Filter $1-
  DLF.Priv.QueryOpen $1-
  DLF.Priv.CommonChan $1-
  DLF.Priv.RegularUser ctcp $1-
  DLF.Win.Echo $event Private $nick $1-
  halt
}

alias -l DLF.Priv.ctcpReply {
  DLF.Watch.Called DLF.Priv.ctcpReply
  if ($1 == VERSION) {
    DLF.Win.Echo $event Private $nick $1-
    halt
  }
  if ($hiswm(ctcp.reply,$1-)) DLF.Win.Filter $1-
  DLF.Priv.QueryOpen $1-
  DLF.Priv.CommonChan $1-
  DLF.Priv.RegularUser ctcpreply $1-
  DLF.Win.Echo $event Private $nick $1-
  halt
}

alias -l DLF.Priv.RegularUser {
  if (%DLF.private.regular != 1) return
  DLF.Watch.Called DLF.Priv.RegularUser
  if ($DLF.IsRegularUser($nick)) {
    var %type $lower($replace($1,-,$space))
    if (%type isin normal text) %type = message
    DLF.Watch.Log Blocked: Private %type from regular user
    DLF.Status Blocked: Private %type from regular user $nick $br($address)
    DLF.Win.Log Filter Blocked Private $nick Private %type from regular user $nick $br($address) $+ :
    DLF.Win.Filter $2-
  }
}

alias -l DLF.Priv.ctcpBlock {
  DLF.Win.Log Filter ctcp Private $nick $1-
  var %comchan $comchan($nick,0)
  ; Block finger requests
  if (($1 == FINGER) && (%DLF.nofingers == 1)) {
    while (%comchan) {
      DLF.Win.Echo Blocked $comchan($nick,%i) $nick ctcp finger
      dec %comchan
    }
    DLF.Status Blocked: ctcp finger from $nick
    DLF.Halt Halted: ctcp finger blocked
  }
  ; dlFilter ctcp response only to people who are in a common channel or in chat
  if (($query($nick)) || ($chat($nick,0)) || (%comchan > 0)) return
  DLF.Watch.Log Blocked: ctcp $1 from $nick with no common dlF channel or chat
  DLF.Win.Filter $1-
}

alias -l DLF.Priv.ctcpreplyVersion {
  var %msg VERSION $c(1,9,$DLF.logo Version $DLF.SetVersion by DukeLupus & Sophist.) $+ $c(1,15,$space $+ Get it from $c(12,15,$u(https://github.com/DukeLupus/dlFilter/)))
  .DLF.ctcpreply $nick %msg
  DLF.Win.Log Filter ctcpsend Private $nick %msg
}

; ========== away responses ==========
alias -l DLF.Away.Filter {
  DLF.Watch.Called DLF.Away.Filter
  if (%DLF.filter.aways == 1) DLF.Win.Filter $3-
}

; ==========  Filtering Stats in titlebar ==========
alias -l DLF.Stats.Count { if (($1 != Private) && ($1 != $hashtag)) hinc -m DLF.stats $+($network,$1,|,$2) }
alias -l DLF.Stats.Get { return $hget(DLF.stats,$+($network,$1,|,$2)) }
alias -l DLF.Stats.TitleText { return $+(dlFilter efficiency:,$space,$1,%) }

alias -l DLF.Stats.Active {
  ; titlebar = window -=- existing text -=- dlF stats
  ; so window name appears in taskbar button
  var %total $DLF.Stats.Get($active,Total)
  var %filter $DLF.Stats.Get($active,Filter)
  if (($DLF.Chan.IsDlfChan($active)) && (%total != $null) && (%filter != $null)) {
    var %percent %filter / %total
    %percent = %percent * 100
    if (%percent < 99) %percent = $round(%percent,1)
    elseif ((%percent < 100) && ($regex(DLF.Stats.Display,%percent,/([0-9]*\.9*[0-8])/) > 0)) %percent = $regml(DLF.Stats.Display,1)
    DLF.Stats.Titlebar $active $DLF.Stats.TitleText(%percent)
  }
  else DLF.Stats.Titlebar
}

alias -l DLF.Stats.Titlebar {
  var %tb $titlebar
  var %re $+(/(-=-\s+)?(#\S*\s+)?,$replace($DLF.Stats.TitleText([0-9.]+),$space,\s+),/F)
  ; Can't use $1- directly in $regsubex because it uses these internally
  var %txt $1-
  if ($regex(DLF.Stats.Titlebar,%tb,%re) > 0) %tb = $regsubex(DLF.Stats.Titlebar,%tb,%re,$null)
  if (%DLF.titlebar.stats == 1) %tb = %tb -=- %txt
  while ($gettok(%tb,1,$asc($space)) == -=-) %tb = $deltok(%tb,1,$asc($space))
  while ($gettok(%tb,-1,$asc($space)) == -=-) %tb = $deltok(%tb,-1,$asc($space))
  titlebar %tb
}

; ========== Ops advertising ==========
alias -l DLF.Ops.AdvertsEnable {
  if (%DLF.ops.advertchan == 1) {
    var %secs %DLF.ops.advertchan.period * 60
    ; only reissue timer if it has changed to avoid cancelling partial countdown and starting it again every time you save options
    if ($timer(DLF.Adverts).delay != %secs) .timerDLF.Adverts -io 0 %secs .signal DLF.Ops.AdvertChan
  }
  else .timerDLF.Adverts off
}

alias -l DLF.Ops.Advert@search {
}

alias -l DLF.Ops.Advert@find {
  var %idx $+($network,@,$nick)
  if (!$hfind(DLF.ops.verRequested,%idx)) DLF.Ops.RequestVersion $nick
  elseif ((!$hfind(DLF.ops.advert@find,%idx)) $&
    && ($hfind(DLF.ops.mirc@find,%idx)) $&
    && (!$hfind(DLF.ops.dlfVersion,%idx))) {
    hadd -mzu86400 DLF.ops.advert@find %idx 86400
    %msg = $c(1,9,$DLF.logo Make @find easier to use by installing the dlFilter mIRC script which collects the results together into a single window. Download it from $u($c(2,https://github.com/DukeLupus/dlFilter/)) $+ .)
    .DLF.notice $nick %msg
    DLF.Win.Log Filter notice Private $nick %msg
  }
}

on *:signal:DLF.Ops.AdvertChan: { DLF.Ops.AdvertChan $1- }
alias -l DLF.Ops.AdvertChan { scon -a DLF.Ops.AdvertChanNet }

alias -l DLF.Ops.AdvertChanNet {
  if ($server == $null) continue
  var %i $chan(0)
  while (%i) {
    var %c $chan(%i)
    dec %i
    ; skip advertising if another user has advertised in the channel
    if ([ [ $+(%,DLF.opsnochanads.,$network,%c) ] ] != $null) {
      unset [ $+(%,DLF.opsnochanads.,$network,%c) ]
      continue
    }
    if (($DLF.Chan.IsDlfChan(%c,$false),$asc($comma)) && ($me isop %c)) {
      var %msg $c(1,9,$DLF.logo Are the responses to your requests getting lost in the crowd? Are your @find responses spread about? If you are using mIRC as your IRC client, then download dlFilter from $u($c(2,https://github.com/DukeLupus/dlFilter/)) and make your time in %c less stressful.)
      if (%DLF.ops.advertchan.filter == 1) {
        .msg %c %msg
        DLF.Win.Log Filter text %c $me %msg
      }
      else msg %c %msg
    }
  }
}

alias -l DLF.Ops.NickChg {
  if (%DLF.ops.advertpriv == 0) return
  if ($1 == $me) return
  var %idx $+($network,@,$nick)
  if (!$hfind(DLF.ops.verRequested,%idx)) return
  DLF.Watch.Called DLF.Ops.NickChg
  var %tables advert@find verRequests verRequested dlfUsers sbcUsers mircUsers privateAd
  var %i = $numtok(%tables,$asc($space)), %oldidx = $+($network,@,$nick), %newidx $+($network,@,$newnick)
  while (%i) {
    var %hash $+(DLF.ops.,$gettok(%tables,%i,$asc($space)))
    var %value $hget(%hash,%oldidx)
    if (%value) {
      var %unset $hget(%hash,%oldidx).unset
      var %sw -m
      if (%value == %unset) var %sw = %sw $+ z
      if (%unset) var %sw = $+(%sw,u,%unset)
      hadd %sw %hash %newidx %value
      hdel %hash %oldidx
    }
    dec %i
  }
}

on *:signal:DLF.Ops.RequestVersion: { DLF.Ops.RequestVersion $1- }
alias -l DLF.Ops.RequestVersion {
  if (%DLF.ops.advertpriv == 0) return
  if ($1 == $me) return
  if ($DLF.IsRegularUser($1) == $false) return
  DLF.Watch.Called DLF.Ops.RequestVersion
  var %idx $+($network,@,$1)
  if ($hfind(DLF.ops.verRequested,%idx)) DLF.Watch.Log OpsAdvert: version already checked
  elseif ($hfind(DLF.ops.mircUsers,%idx)) DLF.Watch.log OpsAdvert: SPOOKY: mircUsers without verRequested
  elseif ($hfind(DLF.ops.dlfUsers,%idx)) DLF.Watch.log OpsAdvert: SPOOKY: dlfUsers without verRequested
  elseif ($hfind(DLF.ops.sbcUsers,%idx)) DLF.Watch.log OpsAdvert: SPOOKY: sbcUsers without verRequested
  else {
    hadd -mzu120 DLF.ops.verRequests %idx 120
    hadd -mzu86400 DLF.ops.verRequested %idx 86400
    .DLF.ctcp $1 VERSION
    DLF.Win.Log Filter ctcpsend Private $1 VERSION
  }
}

alias -l DLF.Ops.VersionReply {
  DLF.Watch.Called DLF.Ops.VersionReply
  var %idx $+($network,@,$nick)
  if (!$hfind(DLF.ops.verRequests,%idx)) return
  ; Allow 5 seconds for further VERSION responses
  hadd -mzu5 DLF.ops.verRequests %idx 5
  var %re /(?:^|\s)(?:v|ver|version)\s*([0-9.]+)(?:\s|$)/F
  var %mod $DLF.strip($2)
  var %regex $regex(DLF.Ops.VersionReply,$3-,%re)
  if (%regex > 0) var %ver $regml(DLF.Ops.VersionReply,1)
  else var %ver ?
  if ((%mod == $strip($DLF.Logo)) && (%ver isnum)) {
    if (!$hfind(DLF.ops.dlfUsers,%idx)) {
      hadd -mu86400 DLF.ops.dlfUsers %idx %ver
      DLF.Watch.Log dlf version added
    }
    else DLF.Watch.Log dlf version already known
  }
  elseif ((%mod == sbClient) && (%ver isnum)) {
    if (!$hfind(DLF.ops.sbcUsers,%idx)) {
      hadd -mu86400 DLF.ops.sbcUsers %idx %ver
      DLF.Watch.Log sbc version added
    }
    else DLF.Watch.Log sbc version already known
  }
  elseif (%mod == mIRC) {
    if (!$hfind(DLF.ops.mircUsers,%idx)) {
      hadd -mu86400 DLF.ops.mircUsers %idx %ver
      DLF.Watch.Log mirc version added
      ; Wait 1s for advertising to allow for any more version messages
      .timer 1 1 .signal DLF.Ops.AdvertPrivDLF $nick
    }
    else DLF.Watch.Log mirc version already known
  }
  DLF.Win.Filter $1-
}

on *:signal:DLF.Ops.AdvertPrivDLF: { DLF.Ops.AdvertPrivDLF $1- }
alias -l DLF.Ops.AdvertPrivDLF {
  DLF.Watch.Called DLF.Ops.AdvertPrivDLF
  var %idx $+($network,@,$1)
  if ($hfind(DLF.ops.privateAd,%idx)) return
  hadd -mu86400 DLF.ops.privateAd %idx $ctime
  var %mircVer $hget(DLF.ops.mircUsers,%idx)
  var %dlfVer $hget(DLF.ops.dlfUsers,%idx)
  var %sbcVer $hget(DLF.ops.sbcUsers,%idx)
  var %msg
  if (%mircVer != $null) {
    if (%mircVer >= %DLF.version.web.mirc) var %mircupgr
    else var %mircupgr You will need to upgrade to mIRC version %DLF.version.web.mirc or higher to use it.
    var %dl from $u($c(2,https://github.com/DukeLupus/dlFilter/)) $+ .
    if (%dlfVer == $null) {
      ; mIRC but no dlF
      %msg = I see you are running mIRC. Have you considered running the dlFilter script to hide everyone else's searches and file requests, and improve your @file requests? %mircupgr You can download dlFilter %dl
      DLf.Watch.Log Advertised dlF via notice.
    }
    elseif (%dlfVer < %DLF.version.web) {
      if (%dlfVer < 1.17) var %downmeth which you can download %dl
      else var %downmeth by clicking on the Update button in the dlFilter Options dialog.
      %msg = I see you are running dlFilter. This notice is to let you know that a newer version is available %downmeth %mircupgr
      DLF.Watch.Log Advertised dlF upgrade via notice.
    }
    if (%msg) {
      %msg = $c(1,9,$DLF.logo %msg)
      .DLF.notice $1 %msg
      DLF.Win.Log Filter notice Private $1 %msg
    }
    if (($false) && (%sbcVer == $null) && ($nopath($script(1) != sbclient.mrc))) {
      DLF.Watch.Log Advertised sbc via notice.
      if (%msg == $null) %msg = I see you are running mIRC. Have you considered
      else %msg = You may also want to consider
      %msg = %msg running the sbClient script to make processing @search and server file-list results easier. You can download sbClient from $u($c(2,https://github.com/SanderSade/sbClient/releases)) $+ .
      .DLF.notice $1 %msg
      DLF.Win.Log Filter notice Private $1 %msg
    }
  }
}

; ========== DCC Send ==========
alias -l DLF.DccSend.Request {
  DLF.Watch.Called DLF.DccSend.Request : $1-
  var %trig $strip($1)
  var %fn $replace($strip($2-),$tab $+ $space,$space,$tab,$null)
  hadd -mz DLF.dccsend.requests $+($network,|,$chan,|,%trig,|,$replace(%fn,$space,_),|,$encode(%fn)) 86400
  DLF.Watch.Log Request recorded: %trig %fn
}

alias -l DLF.DccSend.GetRequest {
  var %fn $replace($noqt($DLF.GetFileName($1-)),$space,_)
  var %req $hfind(DLF.dccsend.requests,$+($network,|*|!,$nick,|,%fn,|*),1,w).item
  if (%req) return %req
  if (*_results_for__*.txt.zip iswm %fn) {
    var %srch $gettok(%fn,1,$asc(.))
    var %pos 0 - $pos(%srch,__,1)
    dec %pos
    var %srch $right(%srch,%pos)
    var %req $hfind(DLF.dccsend.requests,$+($network,|*|@search*|,%srch,|*),1,w).item
    if (%req) return %req
  }
  var %req $hfind(DLF.dccsend.requests,$+($network,|*|@,$nick,|*|*),1,w).item
  if (%req) return %req
  return $hfind(DLF.dccsend.requests,$+($network,|*|@,$nick,-*|*|*),1,w).item
}

alias -l DLF.DccSend.IsRequest {
  var %fn $noqt($DLF.GetFileName($1-))
  var %req $DLF.DccSend.GetRequest(%fn)
  if (%req == $null) return $false
  var %trig $gettok(%req,3,$asc(|))
  if (($left(%trig,1) == !) && ($right(%trig,-1) != $nick)) return $false
  if ($left(%trig,1) == @) {
    var %nick $right(%trig,-1)
    if ((($left(%trig,7) != @search) || ($DLF.IsRegularUser($nick))) && (%nick != $nick) && ($gettok(%nick,1,$asc(-)) != $nick)) return $false
    if ($gettok(%fn,-1,$asc(.)) !isin txt zip rar 7z) return $false
  }
  DLF.Watch.Log File request found: %trig $1-
  return $true
}

alias -l DLF.DccSend.IsTrigger {
  var %srch $+($network,|*|*,$nick,|*|*)
  var %i $hfind(DLF.dccsend.requests,%srch,0,w).item
  if (%i == 0) return $false
  while (%i) {
    var %req $hfind(DLF.dccsend.requests,%srch,%i,w).item
    var %chan $gettok(%req,2,$asc(|))
    var %user $gettok($right($gettok(%req,3,$asc(|)),-1),1,$asc(-))
    if ((%user == $nick) && ($nick(%chan,$nick) != $null)) {
      DLF.Watch.Log User request found: %user
      return $true
    }
    dec %i
  }
  return $false
}

alias -l DLF.DccSend.Rejoin {
  var %i $hget(DLF.dccsend.requests,0).item
  while (%i) {
    var %item $hget(DLF.dccsend.requests,%i).item
    dec %i
    var %net $gettok(%item,1,$asc(|))
    if (%net != $network) continue
    var %chan $gettok(%item,2,$asc(|))
    if (%chan != $chan) continue
    var %trig $gettok(%item,3,$asc(|))
    if ($right(%trig,-1) != $nick) continue
    var %fn $decode($gettok(%item,5,$asc(|)))
    DLF.Chan.EditSend %chan %trig %fn
    DLF.Watch.Log $nick rejoined $chan: Request resent: %trig %fn
  }
}

alias -l DLF.DccSend.SendNotice {
  DLF.Watch.Called DLF.DccSend.SendNotice
  var %req $DLF.DccSend.GetRequest($3-)
  if (%req == $null) return
  var %chan $gettok(%req,2,$asc(|))
  DLF.Win.Log Server Notice %chan $nick $1-
  halt
}

alias -l DLF.DccSend.Send {
  DLF.Watch.Called DLF.DccSend.Send
  var %fn $DLF.GetFilename($3-)
  if ($chr(8238) isin %fn) {
    DLF.Win.Echo Blocked Private $nick DCC Send - filename contains malicious unicode U+8238
    DLF.Halt Blocked: DCC Send - filename contains malicious unicode U+8238
  }
  var %trusted $DLF.DccSend.IsTrusted($nick)
  if (%trusted) DLF.Watch.Log User is in your DCC trust list
  if ($DLF.DccSend.IsRequest(%fn)) {
    if ((%DLF.dccsend.autoaccept == 1) && (!%trusted)) DLF.DccSend.TrustAdd
    DLF.DccSend.Receiving %fn
    DLF.Watch.Log Accepted: DCC Send - you requested this file from this server
    return
  }
  if (!%trusted) {
    if (%DLF.dccsend.requested == 1) DLF.DccSend.Block the file was not requested or @ trigger response has invalid filetype
    if (%DLF.dccsend.dangerous == 1) {
      var %ext $nopath($filename)
      var %ext $gettok(%ext,-1,$asc(.))
      var %bad exe pif application gadget msi msp com scr hta cpl msc jar bat cmd vb vbs vbe js jse ws wsf mrc doc wsc wsh ps1 ps1xml ps2 ps2xml psc1 psc2 msh msh1 msh2 mshxml msh1xml msh2xml scf lnk inf reg doc xls ppt docm dotm xlsm xltm xlam pptm potm ppam ppsm sldm
      if ($istok(%bad,%ext,$asc($space))) DLF.DccSend.Block dangerous filetype
    }
    if (%DLF.dccsend.trusted == 1) DLF.DccSend.Block the user is not in your DCC Get trust list
    if ((%DLF.dccsend.nocomchan == 1) && ($comchan($nick,0) == 0)) DLF.DccSend.Block the user is not in a common channel
    if ((%DLF.dccsend.regular == 1) && ($DLF.IsRegularUser($nick)) DLF.DccSend.Block the user is a regular user
  }
  DLF.Watch.Log DCC Send accepted
  DLF.DccSend.Receiving %fn
}

alias -l DLF.DccSend.Block {
  dcc reject
  DLF.Watch.Log Blocked: dcc send from $nick - $1-
  DLF.Status Blocked: DCC Send from $nick $br($address) because $1- $+ : $filename
  DLF.Status If this file was requested add this nick to your DCC trusted list with $+ $c(4,$color(Background),$space,/dcc trust $nick,$space) $+ and retry your request.
  DLF.Win.Log Filter Blocked Private $nick DCC Send from $nick $br($address) because $1-
  DLF.Win.Filter DCC SEND $filename
}

alias -l DLF.DccSend.Receiving {
  var %req $DLF.DccSend.GetRequest($1-)
  if (%req == $null) return
  var %chan $gettok(%req,2,$asc(|))
  var %origfn $decode($gettok(%req,5,$asc(|)))
  if (%origfn == $null) %origfn = $1-
  var %secs 86400 - $hget(DLF.dccsend.requests,%req)
  DLF.Win.Log Server ctcp %chan $nick DCC Get of $qt(%origfn) from $nick starting $br(waited $duration(%secs,3))
}

alias -l DLF.DccSend.Taskbar {
  ;if ($gettok($titlebar,1-2,$asc($space)) == Get $get(-1)) titlebar $gettok($titlebar,3-,$asc($space))
}

alias -l DLF.DccSend.FileRcvd {
  DLF.DccSend.Taskbar
  var %fn $nopath($filename)
  DLF.Watch.Called DLF.DccSend.FileRcvd %fn
  var %req $DLF.DccSend.GetRequest(%fn)
  if (%req == $null) return
  .hdel DLF.dccsend.requests %req
  var %chan $gettok(%req,2,$asc(|))
  var %dur $get(-1).secs
  var %trig $gettok(%req,3,$asc(|))
  var %origfn $decode($gettok(%req,5,$asc(|)))
  if (%origfn == $null) %origfn = %fn
  var %hash $encode(%trig %origfn)
  if ($hget(DLF.dccsend.retries,%hash)) .hdel DLF.dccsend.retries %hash
  var %bytes $get(-1).rcvd / %dur
  DLF.Win.Log Server ctcp %chan $nick DCC Get of $qt(%origfn) from $nick complete $br($duration(%dur,3) $bytes(%bytes).suf $+ /Sec)
  ; Some servers change spaces to underscores
  ; But we cannot rename if Options / DCC / Folders / Command is set
  ; because it would run after this using the wrong filename
  if ((%origfn != $null) $&
   && (%fn != %origfn) $&
   && ($DLF.DccSend.IsNotGetCommand(%fn)) $&
   && ($left(%trig,1) == !) $&
   && (. isin $gettok(%origfn,-1,$asc($space)))) {
    var %oldfn $qt($filename)
    var %newfn $qt($+($noqt($nofile($filename)),%origfn))
    DLF.Watch.Log Renaming %oldfn to %newfn
    if ($isfile(%newfn)) .remove %newfn
    .rename $qt($filename) $qt($+($noqt($nofile($filename)),%origfn))
  }
}

; Check that there is no mIRC Options / DCC / Folders / Command for the file
alias -l DLF.DccSend.IsNotGetCommand {
  var %i -1
  while ($true) {
    inc %i
    var %get $DLF.mIRCini(extensions,%i)
    if (%get == $null) break
    var %p $poscs(%get,EXTCOM:,0)
    if (%p == 0) continue
    var %p $poscs(%get,EXTDIR:,1)
    if (%p == $null) continue
    dec %p
    var %match $left(%get,%p)
    var %j $numtok(%match,$asc($comma))
    while (%j) {
      if ($gettok(%match,%j,$asc($comma)) iswm $1-) return $false
      dec %j
    }
  }
  return $true
}

alias -l DLF.DccSend.GetFailed {
  DLF.DccSend.Taskbar
  var %fn $nopath($filename)
  DLF.Watch.Called DLF.DccSend.GetFailed : %fn
  var %req $DLF.DccSend.GetRequest(%fn)
  if (%req == $null) return
  .hdel -s DLF.dccsend.requests %req
  var %chan $gettok(%req,2,$asc(|))
  var %trig $gettok(%req,3,$asc(|))
  var %origfn $decode($gettok(%req,5,$asc(|)))
  if (%origfn == $null) %origfn = %fn
  var %hash $encode(%trig %origfn)
  var %retry %DLF.serverretry
  if (%retry) {
    var %attempts $hget(DLF.dccsend.retries,%hash)
    if (%attempts == $null) {
      ; First retry
      .hadd -m DLF.dccsend.retries %hash 1
    }
    elseif (%attempts == 3) {
      .hdel DLF.dccsend.retries %hash
      %retry = $false
    }
    else {
      .hinc DLF.dccsend.retries %hash
    }
  }
  var %bytes $get(-1).rcvd / $get(-1).secs
  var %retrying
  if (%retry) %retrying = - $c(3,retrying)
  DLF.Win.Log Server ctcp %chan $nick DCC Get of %origfn from $nick incomplete $br($duration(%dur,3) $bytes(%bytes).suf $+ /Sec) %retrying
  if (%retry) DLF.Chan.EditSend %chan %trig $decode($gettok(%req,5,$asc(|)))
}

alias -l DLF.DccSend.TrustAdd {
  var %addr $DLF.TimerAddress
  var %desc $nick
  if (%addr != $nick) %desc = %desc $br(%addr)
  [ $+(.timer,$DLF.DccSend.TrustTimer) ] 1 10 .signal DLF.DccSend.TrustRemove %addr %desc
  .dcc trust %addr
  DLF.Watch.Log Trust: Added %desc
}

on *:signal:DLF.DccSend.TrustRemove: DLF.DccSend.TrustRemove $1-
alias -l DLF.DccSend.TrustRemove {
  .dcc trust -r $1
  DLF.Watch.Log Trust: Removed $2-
}

alias -l DLF.DccSend.TrustTimer { return DLFRemoveTrust $+ $DLF.TimerAddress }

alias -l DLF.DccSend.IsTrusted {
  if ($timer($DLF.DccSend.TrustTimer) != $null) return $false
  var %addr $address($1,5)
  if (%addr == $null) return $false
  var %i $trust(0)
  while (%i) {
    var %trust $trust(%i)
    if (($numtok(%trust,$asc(!)) < 2) && (%trust == $gettok(%addr,1,$asc(!)))) return $true
    if ($trust(%i) iswm %addr) return $true
    dec %i
  }
  return $false
}

alias DLF.Requests {
  echo -a $crlf
  echo -a dlFilter: Current file requests:
  echo -a --------------------------------
  var %i $hget(DLF.dccsend.requests,0).item
  if (%i == 0) {
    echo -a No requests
    return
  }
  var %list
  while (%i) {
    var %secs $hget(DLF.dccsend.requests,%i).data
    var %item $hget(DLF.dccsend.requests,%i).item
    var %trig $gettok(%item,3,$asc(|))
    var %file $decode($gettok(%item,5,$asc(|)))
    %list = $addtok(%list,%secs %trig %file,$asc(|))
    dec %i
  }
  %list = $sorttok(%list,$asc(|),nr)
  %i = $numtok(%list,$asc(|))
  while (%i) {
    var %item $gettok(%list,%i,$asc(|))
    var %time $ctime - 86400
    %time = %time + $gettok(%item,1,$asc($space))
    echo -a $asctime(%time,$timestampfmt) $gettok(%item,2-,$asc($space))
    dec %i
  }
}

alias -l DLF.DccChat.ChatNotice {
  DLF.Watch.Called DLF.DccChat.ChatNotice
  if ((%DLF.private.nocomchan == 1) && ($comchan($nick,0) == 0)) {
    DLF.Watch.Log DCC CHAT will be blocked: No common channel
    DLF.Win.Log Filter Warning Private $nick DCC Chat will be blocked because user is not in a common channel:
    DLF.Win.Filter $1-
  }
  DLF.Priv.RegularUser DCC-Chat-Notice $1-
  DLF.Win.Echo $event Private $nick $1-
  halt
}

alias -l DLF.DccChat.Chat {
  DLF.Watch.Called DLF.DccChat.Chat
  if ((%DLF.private.nocomchan == 1) && ($comchan($nick,0) == 0)) {
    DLF.Watch.Log Blocked: DCC CHAT from $nick - No common channel
    DLF.Status Blocked: DCC CHAT from $nick - No common channel
    DLF.Win.Log Filter Blocked Private $nick DCC Chat because user is not in a common channel:
    DLF.Win.Filter $1-
  }
  DLF.Priv.RegularUser DCC-CHAT $1-
  DLF.Watch.Log DCC Chat accepted.
}

; Hopefully handling a dcc chat open event is unnecessary because he have halted unwanted requests
alias -l DLF.DccChat.Open {
  DLF.Watch.Called DLF.DccChat.Open
  echo -stf DLF.DccChat.Open called: target $target nick $nick args $1-
}

; ========== Custom Filters ==========
alias -l DLF.Custom.Filter {
  DLF.Watch.Called DLF.Custom.Filter
  if ($left($chan,1) isin $chantypes) var %filt chan $+ $event
  else var %filt priv $+ $event
  var %hiswm $+(custfilt.,%filt)
  var %hash $+(DLF.,%hiswm)
  if ($hget(%hash) == $null) DLF.Custom.CreateHash %filt
  elseif ($hget(%hash,0).item != $numtok([ [ $+(%,DLF.custom.,%filt) ] ],$asc($comma))) DLF.Custom.CreateHash %filt
  var %match = $hiswm(%hiswm,$DLF.strip($1-))
  if (%match) {
    DLF.Watch.Log Matched in custom. $+ %filt $+ : %match
    DLF.Win.Filter $1-
  }
}

alias -l DLF.Custom.Add {
  DLF.Watch.Called DLF.Custom.Add $1-
  if ($2- == *) return
  var %type $replace($1,$nbsp,$space)
  var %new = $trim($2-)
  if ($0 == 2) %new = $+(*,%new,*)
  %new = $replace(%new,$comma,?,$+($space,$space,*),$+($space,*),$+(*,$space,$space),$+(*,$space),**,*)
  if (%type == Channel text) DLF.Custom.Set chantext $addtok(%DLF.custom.chantext,%new,$asc($comma))
  elseif (%type == Channel action) DLF.Custom.Set chanaction $addtok(%DLF.custom.chanaction,%new,$asc($comma))
  elseif (%type == Channel notice) DLF.Custom.Set channotice $addtok(%DLF.custom.channotice,%new,$asc($comma))
  elseif (%type == Channel ctcp) DLF.Custom.Set chanctcp $addtok(%DLF.custom.chanctcp,%new,$asc($comma))
  elseif (%type == Private text) DLF.Custom.Set privtext $addtok(%DLF.custom.privtext,%new,$asc($comma))
  elseif (%type == Private action) DLF.Custom.Set privaction $addtok(%DLF.custom.privaction,%new,$asc($comma))
  elseif (%type == Private notice) DLF.Custom.Set privnotice $addtok(%DLF.custom.privnotice,%new,$asc($comma))
  elseif (%type == Private ctcp) DLF.Custom.Set privctcp $addtok(%DLF.custom.privctcp,%new,$asc($comma))
  else DLF.Error DLF.Custom.Add Invalid message type: %type
}

alias -l DLF.Custom.Remove {
  DLF.Watch.Called DLF.Custom.Remove $1-
  var %type $replace($1,$nbsp,$space)
  if (%type == Channel text) DLF.Custom.Set chantext $remtok(%DLF.custom.chantext,$2-,1,$asc($comma))
  elseif (%type == Channel action) DLF.Custom.Set chanaction $remtok(%DLF.custom.chanaction,$2-,1,$asc($comma))
  elseif (%type == Channel notice) DLF.Custom.Set channotice $remtok(%DLF.custom.channotice,$2-,1,$asc($comma))
  elseif (%type == Channel ctcp) DLF.Custom.Set chanctcp $remtok(%DLF.custom.chanctcp,$2-,1,$asc($comma))
  elseif (%type == Private text) DLF.Custom.Set privtext $remtok(%DLF.custom.privtext,$2-,1,$asc($comma))
  elseif (%type == Private action) DLF.Custom.Set privaction $remtok(%DLF.custom.privaction,$2-,1,$asc($comma))
  elseif (%type == Private notice) DLF.Custom.Set privnotice $remtok(%DLF.custom.privnotice,$2-,1,$asc($comma))
  elseif (%type == Private ctcp) DLF.Custom.Set privctcp $remtok(%DLF.custom.privctcp,$2-,1,$asc($comma))
  else DLF.Error DLF.Custom.Remove Invalid message type: %type
}

alias -l DLF.Custom.Set {
  var %var $+(%,DLF.custom.,$1)
  [ [ %var ] ] = $2-
  DLF.Custom.CreateHash $1
}

alias -l DLF.Custom.CreateHash {
  var %hash $+(DLF.custfilt.,$1)
  var %filt [ [ $+(%,DLF.custom.,$1) ] ]
  if ($hget(%hash)) hfree %hash
  hmake %hash 10
  var %i $numtok(%filt,$asc($comma))
  while (%i) {
    hadd %hash %i $gettok(%filt,%i,$asc($comma))
    dec %i
  }
}

; ========== Custom Window handling ==========
menu @dlF.Filter.* {
  Search: DLF.Search.Show $menu $?="Enter search string"
  -
  $iif(%DLF.win-filter.timestamp == 1,$style(1)) Timestamp: DLF.Options.ToggleOption filtered.timestamp
  $iif(%DLF.win-filter.strip == 1,$style(1)) Strip codes: DLF.Options.ToggleOption filtered.strip
  $iif(%DLF.win-filter.wrap == 1,$style(1)) Wrap lines: DLF.Options.ToggleOption filtered.wrap
  $iif(%DLF.win-filter.log == 1,$style(1)) Log: DLF.Options.ToggleOption filtered.log
  -
  $iif(%DLF.showfiltered,Hide,Show) filter window(s): DLF.Options.ToggleShowFilter
  Clear: clear
  Options: DLF.Options.Show
  -
}

menu @dlF.Server.* {
  Search: DLF.Search.Show $menu $?="Enter search string"
  -
  $iif(%DLF.win-server.timestamp == 1,$style(1)) Timestamp: DLF.Options.ToggleOption server.timestamp
  $iif(%DLF.win-server.strip == 1,$style(1)) Strip codes: DLF.Options.ToggleOption server.strip
  $iif(%DLF.win-server.wrap == 1,$style(1)) Wrap lines: DLF.Options.ToggleOption server.wrap
  $iif(%DLF.win-server.log == 1,$style(1)) Log: DLF.Options.ToggleOption server.log
  -
  Clear: clear
  Options: DLF.Options.Show
  Close: {
    %DLF.serverwin = 0
    close -@ @DLF.Server*.*
  }
  -
}

alias -l DLF.Win.Filter {
  DLF.Win.Log Filter $event $DLF.chan $nick $1-
  halt
}

alias -l DLF.Win.Server {
  DLF.Win.Log Server $event $DLF.chan $nick $1-
  halt
}

alias -l DLF.Win.Log {
  if (($window($4)) && ($event == open)) .window -c $4
  elseif ($dqwindow & 4) close -d
  var %type $1
  if (($1 == Filter) && ($2 != ctcpsend) && ($4 != $me)) {
    if ($3 != $hashtag) DLF.Stats.Count $3 Filter
    else {
      var %i $comchan($4,0)
      while (%i) {
        var %chan $comchan($4,%i)
        if ($DLF.Chan.IsDlfChan(%chan)) DLF.Stats.Count %chan Filter
        dec %i
      }
    }
  }
  elseif ($1 == Server) {
    DLF.Chan.SetNickColour
    if (%DLF.serverwin == 0) {
      DLF.Win.Echo $2-
      return
    }
  }
  if (%type == server) {
    var %log   %DLF.win-server.log
    var %ts    %DLF.win-server.timestamp
    var %strip %DLF.win-server.strip
    var %wrap  %DLF.win-server.wrap
  }
  else {
    var %log   %DLF.win-filter.log
    var %ts    %DLF.win-filter.timestamp
    var %strip %DLF.win-filter.strip
    var %wrap  %DLF.win-filter.wrap
  }

  var %line $DLF.Win.LineFormat($2-)
  if (%log == 1) write $DLF.Win.LogName($DLF.Win.WinName(%type)) $logstamp $strip(%line)
  if ((%type = Filter) && (%DLF.showfiltered == 0) && (%DLF.background == 0)) {
    DLF.Watch.Log Dropped: Options set to not show filters
    return
  }

  var %show 1, %tb
  if (%type == Filter) {
    %tb = Filtered
    %show = %DLF.showfiltered
  }
  elseif (%type == Server) %tb = Server response
  var %win $DLF.Win.WinOpen(%type,-k0nw,%log,%show,%tb $DLF.Win.TbMsg)
  DLF.Win.CustomTrim %win
  if (%ts == 1) %line = $timestamp %line
  if (%strip == 1) %line = $strip(%line)
  var %col $color($DLF.Win.MsgType($2))
  if (%wrap == 1) aline -pi %col %win %line
  else aline %col %win %line
  DLF.Search.Add %win %wrap %col %line
  DLF.Watch.Log Filtered: To %win
}

alias -l DLF.Win.Ads {
  DLF.Watch.Called DLF.Win.Ads
  DLF.Chan.SetNickColour
  DLF.Ads.Add $1-
  DLF.Win.Filter $1-
}

alias -l DLF.Win.IsInvalidSelection {
  var %i $sline($menu,0)
  if (%i == $null) return $true
  if (%i == 0) return $true
  var %min $DLF.Win.MinSelectLine
  while (%i) {
    if ($sline($menu,%i).ln >= %min) return $false
    dec %i
  }
  return $true
}

alias -l DLF.Win.MinSelectLine {
  if ($window($active).type != listbox) DLF.Error DLF.Win.MinSelectLine attempted on non-listbox window: $active
  var %max $min($line($active,0),20)
  var %i 1
  while (%i <= %max) {
    var %l $line($active,%i)
    inc %i
    if (%l == $crlf) return %i
  }
  return 1
}

alias -l DLF.Win.NickFromTag {
  var %nick $replace($strip($1),$tab,$null)
  if ($left(%nick,1) == $lt) %nick = $right(%nick,-1)
  if ($right(%nick,1) == $gt) %nick = $left(%nick,-1)
  while ($left(%nick,1) isin $prefix) %nick = $right(%nick,-1)
  return %nick
}

alias -l DLF.Win.TbMsg {
  if (%DLF.perconnect) var %per the $network network
  else var %per all networks
  return messages from %per -=- Right-click for options
}

alias -l DLF.Win.WinName {
  var %net All
  if (%DLF.perconnect) %net = $network
  return $+(@dlF.,$1,.,%net)
}

alias -l DLF.Win.LogName {
  var %lfn $mklogfn($1)
  if (%DLF.perconnect == 0) %lfn = $nopath(%lfn)
  return $qt($+($logdir,%lfn))
}

; %winname = $DLF.Win.WinOpen(type,switches,log,show,title)
alias -l DLF.Win.WinOpen {
  var %win $DLF.Win.WinName($1)
  if ($window(%win)) return %win
  var %lfn $DLF.Win.LogName(%win)
  var %switches $2
  if (%DLF.perconnect == 0) %switches = $puttok(%switches,$gettok(%switches,1,$asc($space)) $+ z,1,$asc($space))
  if ((%DLF.background == 1) && ($4 == 0)) %switches = $puttok(%switches,$gettok(%switches,1,$asc($space)) $+ h,1,$asc($space))
  window %switches %win
  if (($3) && ($isfile(%lfn))) loadbuf $windowbuffer -rpi %win %lfn
  if ($4- != $null) titlebar %win -=- $5-
  return %win
}

alias -l DLF.Win.LineFormat {
  tokenize $asc($space) $1-
  var %nc
  if (%DLF.perconnect == 0) %nc = $network
  if (($left($2,1) isin $chantypes) && ($2 != $hashtag)) %nc = %nc $+ $2
  if (%nc != $null) %nc = $sbr(%nc)
  return %nc $DLF.Win.Format($1-)
}

alias -l DLF.Win.MsgType return $replace($1,text,normal,textsend,normal,actionsend,action,noticesend,notice,ctcpsend,ctcp,ctcpreply,ctcp,ctcpreplysend,ctcp)

alias -l DLF.Win.Format {
  tokenize $asc($space) $1-
  var %chan
  if (($2 != Private) && ($2 != $3)) %chan = : $+ $2
  if (($1 isin Normal Text Open) && ($3 == $me) && ($prefixown == 0)) return > $4-
  elseif ($1 isin Normal Text Open) return $tag($DLF.Chan.MsgNick($2,$3)) $4-
  elseif (($1 == TextSend) && ($prefixown == 0)) return > $4-
  elseif ($1 == TextSend) return $tag($DLF.Chan.MsgNick($2,$me)) $4-
  elseif ($1 == Action) return * $3-
  elseif ($1 == ActionSend) return * $me $4-
  elseif ($1 == Notice) return $+(-,$3,-) $4-
  elseif ($1 == NoticeSend) return $+(-,$me,-) $4-
  elseif (($1 == ctcp) && ($4 == DCC)) return $4-
  elseif ($1 == ctcp) return $sbr($3 $+ %chan $4) $5-
  elseif ($1 == ctcpsend) return -> $sbr($3 $+ %chan) $upper($4) $5-
  elseif ($1 == ctcpreply) return $sbr($3 $+ %chan $4 reply) $5-
  elseif ($1 == ctcpreplysend) return -> $sbr($3 $+ %chan) $4-
  elseif ($1 == warning) return $c(1,9,$DLF.logo Warning: $4-)
  elseif ($1 == blocked) return $c(1,9,$DLF.logo Blocked: $4-)
  elseif ($1 == session) return $4-
  else return * $4-
}

alias -l DLF.Win.Echo {
  var %line $DLF.Win.Format($1-)
  var %col $DLF.Win.MsgType($1)
  var %pref
  if ($1 != ctcpreply) %pref = $2 $+ :
  if ($2 == Status) {
    echo -stc %col %line
    DLF.Watch.Log Echoed: To Status Window
  }
  elseif ($2 == @find) {
    var %chans $DLF.@find.IsResponse
    var %i $numtok(%chans,$asc($space))
    while (%i) {
      var %chan $gettok(%chans,%i,$asc($space))
      if ($nick(%chan,$3)) echo -tc %col %chan %pref %line
      else $deltok(%chans,%i,$asc($space))
      dec %i
    }
    if (%chans != $null) DLF.Watch.Log Echoed: To @find channels with $3 $+ : %chans
    else {
      echo -stc %col %pref %line
      DLF.Watch.Log Echoed: To status window
    }
    return
  }
  elseif ($2 !isin Private @find $hashtag) {
    ; mIRC does not support native options for timestamping of custom windows
    var %flags -tc
    if (@#* iswm $2) {
      if (%DLF.win-onotice.timestamp == 0) %flags = -c
      elseif (!$window($2).stamp) %line = $timestamp %line
    }
    echo %flags %col $2 %line
    DLF.Watch.Log Echoed: To $2
  }
  else {
    var %sent
    var %i $comchan($3,0)
    if ((%i == 0) || ($3 == $me)) {
      if (($window($active).type !isin custom listbox) && ((($DLF.IsServiceUser($3)) && (!$DLF.Event.JustConnected)) || ($3 == $me))) {
        echo -atc %col %pref %line
        DLF.Watch.Log Echoed: To active window $active
      }
      elseif (($usesinglemsg == 0) || ($DLF.IsServiceUser($3))) {
        if ($2 == Private) %pref = $null
        echo -stc %col %pref %line
        DLF.Watch.Log Echoed: To status window
      }
      else {
        if ($2 == Private) %pref = $null
        echo -dtc %col %pref %line
        DLF.Watch.Log Echoed: To single message window
      }
      return
    }
    while (%i) {
      var %chan $comchan($3,%i)
      echo -tc %col %chan %pref %line
      %sent = $addtok(%sent,%chan,$asc($comma))
      dec %i
    }
    DLF.Watch.Log Echoed: To common channels %sent
  }
}

alias -l DLF.Win.NickChg {
  DLF.Watch.Called DLF.Win.NickChg
  if ($query($nick)) {
    DLF.Watch.Log Renaming: Query window $nick to $newnick
    queryrn $nick $newnick
  }
  if ($chat($nick)) DLF.Win.NickChgDCC chat -c $nick $newnick
  if ($send($nick)) DLF.Win.NickChgDCC send -s $nick $newnick
  if ($get($nick)) DLF.Win.NickChgDCC get -g $nick $newnick
  if ($fserve($nick)) DLF.Win.NickChgDCC fserve -f $nick $newnick
}

alias -l DLF.Win.NickChgDCC {
  DLF.Watch.Log Renaming: DCC $1 window $3 to $4
  dcc nick $2-
}

; DLF.Win.ShowHide @dlF.Filter/Ads* 1/0
alias -l DLF.Win.ShowHide {
  if (%DLF.background == 1) {
    var %i $window($1,0)
    while (%i) {
      if ($2 == 1) var %flags -w3
      else var %flags -h
      window %flags $window($1,%i)
      dec %i
    }
  }
  elseif ($2 == 0) close -@ $1
}

; ========== Ads Window ==========
menu @dlF.Ads.* {
  dclick: DLF.Ads.GetList $1
  $iif($DLF.Win.IsInvalidSelection,$style(2)) Get list of files from selected servers: DLF.Ads.GetListMulti
  -
  $iif($DLF.Win.IsInvalidSelection,$style(2)) Report line(s) which shouldn't be considered ads: DLF.Ads.ReportFalse
  -
  .$iif(%DLF.serverads,Hide,Show) ads window(s): DLF.Options.ToggleShowAds
  Clear: clear
  Options: DLF.Options.Show
  -
}

alias -l DLF.Ads.Add {
  if ((%DLF.serverads == 0) && (%DLF.background == 0)) return
  DLF.Watch.Called DLF.Ads.Add
  if (%DLF.perconnect == 1) var %tabs -t20,40
  else var %tabs -t30,55
  var %win $DLF.Win.WinOpen(Ads,-k0nwl %tabs,0,%DLF.serverads,0 %tb)
  if ($line(%win,0) == 0) {
    aline -n 6 %win This window shows adverts from servers describing how many files they have and how to get a list of their files.
    aline -n 2 %win However you will probably find it easier to use "@search search words" (or "@find search words") to locate files you want.
    aline -n 2 %win If you use @search, consider installing the sbClient script to make processing @search results easier.
    aline -n 4 %win You can double-click to have the request for the list of files sent for you.
    aline -n 1 %win $crlf
  }
  var %line $DLF.Win.LineFormat($event $chan $nick $replace($DLF.strip($1-),$tab,$null))
  var %ad $gettok(%line,3-,$asc($space))
  while ($left(%ad,1) == $space) %ad = $right(%ad,-1)
  while ((%ad != $null) && (($left(%ad,1) !isletter) || ($asc($left(%ad,1)) >= 192))) %ad = $deltok(%ad,1,$asc($space))
  while ($wildtok(%ad,@*,0,$asc($space))) {
    var %tok $wildtok(%ad,@*,1,$asc($space))
    %ad = $reptok(%ad,%tok,$b(%tok),$asc($space))
  }
  while ($wildtok(%ad,!*,0,$asc($space))) {
    var %tok $wildtok(%ad,!*,1,$asc($space))
    %ad = $reptok(%ad,%tok,$b(%tok),$asc($space))
  }
  %line = $gettok(%line,1,$asc($space)) $tab $+ $gettok(%line,2,$asc($space)) $tab $+ %ad
  var %nc $chan
  if (%DLF.perconnect == 0) %nc = $+($network,$chan)
  DLF.Ads.AddLine %win %nc $nick %line
}

; DLF.Ads.AddLine win netchan nick line
alias -l DLF.Ads.AddLine {
  if ($fline($1,$4-,0) > 0) {
    DLF.Watch.Log Advert: Identical to existing
    return
  }
  var %srch $DLF.Ads.SearchText($4-)
  var %match $+([,$2,]*,$tag(* $+ $3),*)
  var %i $fline($1,%match,0)
  if (%i == 0) {
    %match = $+([,$2,]*)
    %i = $fline($1,%match,0)
  }
  if (%i == 0) {
    %match = [*]*
    %i = $fline($1,%match,0)
  }
  var %ln $line($1,0) + 1
  while (%i) {
    var %ln $fline($1,%match,%i)
    var %l $line($1,%ln)
    var %s $DLF.Ads.SearchText(%l)
    if (%s == %srch) {
      if ($4- != %l) {
        var %selected
        if ($line($1,%ln).state) %selected = -a
        rline %selected 3 $1 %ln $4-
        DLF.Watch.Log Advert: Replaced
      }
      else DLF.Watch.Log Advert: Not replaced
      break
    }
    elseif (%s < %srch) {
      inc %ln
      iline 3 $1 %ln $4-
      DLF.Watch.Log Advert: Inserted
      break
    }
    dec %i
  }
  if (%i == 0) {
    iline 3 $1 %ln $4-
    DLF.Watch.Log Advert: $nick prepended
  }
  window -b $1
  var %ads $line($1,0) - 5
  var %tb server advertising $DLF.Win.TbMsg
  titleBar $1 -=- %ads %tb
}

alias -l DLF.Ads.SearchText {
  var %s = $strip($1-)
  while ($wildtok(%s,!*,0,$asc($space))) {
    var %tok $wildtok(%s,!*,1,$asc($space))
    %s = $remtok(%s,%tok,0,$asc($space))
  }
  while ($wildtok(%s,@*,0,$asc($space))) {
    var %tok $wildtok(%s,@*,1,$asc($space))
    %s = $remtok(%s,%tok,0,$asc($space))
  }
  %s = $replace($gettok(%s,1-7,$asc($space)),$tab,$null)
  return $puttok(%s,$DLF.Win.NickFromTag($gettok(%s,2,$asc($space))),2,$asc($space))
}

alias -l DLF.Ads.ReportFalse {
  DLF.Watch.Called DLF.Ads.ReportFalse
  var %min $DLF.Win.MinSelectLine
  var %n = $sline($active,0), %i 1, %body
  while (%i <= %n) {
    var %ln $sline($active,%i).ln
    inc %i
    if (%ln < %min) continue
    var %line $strip($line($active,%ln))
    if (%DLF.perconnect == 1) $&
      %line = $puttok(%line,$+([,$network,$right($left($gettok(%line,1,$asc($space)),-1),-1),]),1,$asc($space))
    var %len $len(%body) + $len(%line)
    if (%len > 4000) break
    %body = $+(%body,$crlf,$crlf,```,%line,```))
  }
  var %url $DLF.GitReports(False Positive Ads,$right(%body,-4))
  if (!%url) DLF.Alert Too many lines selected. $+ $crlf $+ You have selected too many lines. Please select fewer lines and try again.
  url -an %url
}

alias -l DLF.Ads.GetListMulti {
  var %i $sline($active,0)
  while (%i) {
    DLF.Ads.GetList $sline($active,%i).ln
    dec %i
  }
}

alias -l DLF.Ads.GetList {
  var %line $strip($line($active,$1))
  DLF.Watch.Called DLF.Ads.GetList %line
  var %re /[[]([^]]+)[]]\s+<[&@%+]*([^>]+?)>.*?\W(@\S+)\s+/Fi
  if ($regex(DLF.Ads.GetList,%line,%re) > 0) {
    var %chan $regml(DLF.Ads.GetList,1)
    var %nick $regml(DLF.Ads.GetList,2)
    var %trig $regml(DLF.Ads.GetList,3)
    var %illegal ,./!¬"£$%&*()+=;:@'~#<>?
    while ($right(%trig,1) isin %illegal) %trig = $left(%trig,-1)
    if ((%trig == @find) || ($left(%trig,7) == @search)) return
    var %net $gettok($active,-1,$asc(.))
    if (%net == All) {
      var %i $scon(0), %notchan, %notnet
      while (%i) {
        scon %i
        var %ln $len($network)
        if ($left(%chan,%ln) == $network) {
          var %c $right(%chan,- $+ %ln)
          if ($left(%c,1) isin $chantypes) {
            if ($me ison %c)) {
              DLF.Chan.EditSend %c %trig
              scon -r
              return
            }
            %notnet = $network
            if ($server) %notchan = %c
          }
        }
        dec %i
      }
      scon -r
      if (%notnet) {
        if (%notchan) DLF.Alert Not on channel %notchan $cr $+ The server list cannot be retrieved. Whilst you are connected to %notnet you are no longer on channel %notchan $+ .
        else DLF.Alert Not connected to %notnet $+ The server list cannot be retrieved. Whilst you have a server window open for %notnet you are disconnected.
      }
      else DLF.Alert Not connected to %notnet $cr $+ The server list cannot be retrieved. You are no longer connected to %notnet $+ .
    }
    ; Use editbox not msg so other scripts (like sbClient) get On Input event
    elseif (%net != $network) DLF.Alert Not connected to $network $ $cr $+ The server list cannot be retrieved from %net because this window is connected to $network instead.
    elseif (%nick ison %chan) DLF.Chan.EditSend %chan %trig
    elseif ($server) DLF.Alert Not on channel %chan $cr $+ The server list cannot be retrieved because you are no longer on %chan $+ .
    else DLF.Alert Not connected to $network $+ The server list cannot be retrieved. Whilst you have a server window open for $network you are disconnected.
  }
}

alias -l DLF.Ads.NickChgMatch {
  var %m $+([,$network,*]*<*,$1,>*)
  if (%DLF.perconnect) %m = $+([*]*<*,$1,>*)
  return %m
}

alias -l DLF.Ads.NickChg {
  var %win $DLF.Win.WinName(Ads)
  if (!$window(%win)) return
  DLF.Watch.Called DLF.Ads.NickChg
  ; Delete any existing lines for $newnick
  var %match $DLF.Ads.NickChgMatch($newnick)
  while (%i) {
    var %ln $fline(%win,%match,%i)
    dec %i
    var %l $line(%win,%ln)
    if ($DLF.Win.NickFromTag($gettok(%l,2,$asc($space))) == $nick) dline %win %ln
  }
  var %match $DLF.Ads.NickChgMatch($nick)
  var %i = $fline(%win,%match,0), %nl $len($network)
  while (%i) {
    var %ln $fline(%win,%match,%i)
    dec %i
    var %l $line(%win,%ln)
    if ($DLF.Win.NickFromTag($gettok(%l,2,$asc($space))) != $nick) continue
    var %nc $left($right($gettok(%l,1,$asc($space)),-1),-1)
    var %chan %nc
    if (%DLF.perconnect == 0) %chan = $right(%nc,- $+ %nl)
    if ((%DLF.perconnect == 1) || (($left(%nc,%nl) == $network) && ($left(%chan,1) isin $chantypes))) {
      var %l $line(%win,%ln)
      %l = $puttok(%l,$tab $+ $tag($DLF.Chan.MsgNick(%chan,$newnick)),2,$asc($space))
      DLF.Watch.Log Renaming Ad line $nick -> $newnick : %l
      ; Delete and re-add to ensure in the correct sort order
      dline %win %ln
      DLF.Ads.AddLine %win %nc $newnick %l
    }
  }
}

; DLF.Ads.ColourLines $event $nick $chan
alias -l DLF.Ads.ColourLines {
  DLF.Watch.Called DLF.Ads.ColourLines $1-
  var %win $DLF.Win.WinName(Ads)
  if (!$window(%win)) return
  var %match $+([,$network,$3,]*)
  if (%DLF.perconnect) %match = $+([,$3,]*)
  if (($1 == quit) || ($1 == disconnect)) {
    var %match $+([,$network,*]*)
    if (%DLF.perconnect) %match = [*]*
  }
  if ($2 != $me) %match = $+(%match,<*,$2,>*)
  var %i $fline(%win,%match,0)
  var %ln - $+ $len($network)
  while (%i) {
    var %l $strip($fline(%win,%match,%i).text)
    var %ln $fline(%win,%match,%i)
    dec %i
    var %chan $left($right($gettok(%l,1,$asc($space)),-1),-1)
    if (%DLF.perconnect == 0) %chan = $right(%chan,%ln)
    if ($left(%chan,1) !isin $chantypes) continue
    var %nick $DLF.Win.NickFromTag($gettok(%l,2,$asc($space)))
    if ($1 == join) {
      if ($nick(%chan,%nick) != $null) {
        DLF.Watch.Log Enabling ad: $gettok(%l,1-7,$asc($space)) …
        DLF.Chan.SetNickColour %nick
        cline 3 %win %ln
      }
      else {
        DLF.Watch.Log Deleting offline ad: $gettok(%l,1-7,$asc($space)) …
        dline %win %ln
      }
    }
    elseif (($1 == disconnect) || (%nick == $2) || ($me == $2)) {
      DLF.Watch.Log Disabling ad: $gettok(%l,1-7,$asc($space)) …
      cline 14 %win %ln
    }
  }
}

; ========== Search within Filter / Server / Watch windows - new lines added dynamically ==========
menu @dlF.*Search.* {
  Copy line: {
    .clipboard
    .clipboard $sline($active,1)
    cline 7 $active $sline($active,1).ln
  }
  Clear: clear
  Close: window -c $active
  Options: DLF.Options.Show
}

on *:input:@dlF.*Search.*: DLF.Search.Show $target $1-

alias -l DLF.Search.Show {
  DLF.Watch.Called DLF.Search.Show $1-
  if ($2 == $null) return
  var %wf $gettok($1,2,$asc(.)), %ws
  if ($right(%wf,6) != Search) %ws = $+(%wf,Search)
  else {
    %ws = %wf
    %wf = $left(%wf,-6)
  }
  var %wf $puttok($1,%wf,2,$asc(.))
  var %ws $puttok($1,%ws,2,$asc(.))
  if ($gettok($1,-1,$asc(.)) == All) var %flags -eabk0z
  else var %flags -eabk0
  window %flags %ws
  var %sstring $+(*,$2-,*)
  titlebar %ws -=- Searching for %sstring in %wf
  filter -wwcbzph4 %wf %ws %sstring
  if ($filtered == 0) var %matches No matches
  elseif ($filtered == 1) var %matches One match
  else var %matches $filtered matches
  var %msg Search complete -=- %matches found for $qt(%sstring) in %wf
  titlebar %ws -=- %msg
  DLF.Watch.Log %msg
}

; Must be called BEFORE the new line is added to the original window.
alias -l DLF.Search.Add {
  var %type = $gettok($1,2,$asc(.))
  var %win $puttok($1,$+(%type,Search),2,$asc(.))
  if (!$window(%win)) return
  var %tb $window(%win).title
  var %match /found for $qt((.*)) in $1/F
  if ($regex(DLF.Search.Add,%tb,%match) == 0) return
  var %wild $regml(DLF.Search.Add,1)
  if (%wild !iswm $4-) {
    if (%type != Watch) return
    if ($3 !isnum 3-4) return
    if ($line($1,$line($1,0)) != $line(%win,$line(%win,0))) return
  }
  if (%type != Watch) DLF.Watch.Called DLF.Search.Add $1-
  if ($2 == 1) aline -pi $3 %win $4-
  else aline $3 %win $4-
}

; ========== @find windows ==========
menu @dlF.@find.* {
  dclick: DLF.@find.Get $1
  $iif($DLF.Win.IsInvalidSelection,$style(2)) Get selected files: {
    var %i $sline($active,0)
    while (%i) {
      DLF.@find.Get $sline($active,%i).ln
      dec %i
    }
  }
  Copy line(s): DLF.@find.CopyLines
  $iif(!$script(AutoGet.mrc),$style(2)) Send to AutoGet: DLF.@find.SendToAutoGet
  $iif(!$script(vPowerGet.net.mrc),$style(2)) Send to vPowerGet.NET: DLF.@find.SendTovPowerGet
  Save results as a text file: DLF.@find.SaveResults
  -
  Options: DLF.Options.Show
  Clear: clear
  -
  Close: window -c $active
  -
}

alias -l DLF.@find.Request {
  hadd -mz DLF.@find.requests $+($network,$chan) 900
}

alias -l DLF.@find.IsResponse {
  var %net = $network $+ *, %ln - $+ $len($network)
  var %n $hfind(DLF.@find.requests,%net,0,w).item
  var %chans
  while (%n) {
    var %netchan $hfind(DLF.@find.requests,%net,%n,w).item
    var %chan $right(%netchan,%ln)
    if (($left(%chan,1) isin $chantypes) && ($nick ison %chan)) {
      DLF.Watch.Log @find.IsResponse: %chan
      %chans = %chan %chans
    }
    dec %n
  }
  DLF.Watch.Called DLF.@find.IsResponse %chans
  return %chans
}

alias -l DLF.@find.Response {
  DLF.Watch.Called DLF.@find.Response
  if ($DLF.@find.IsResponse) {
    DLF.Chan.SetNickColour
    var %txt $DLF.strip($1-)
    DLF.@find.OnlyPartial $1-
    if ($hiswm(find.header,%txt)) {
      if (%DLF.searchresults == 1) DLF.Win.Log Filter $event @find $nick $1-
      else DLF.Win.Log Server $event @find $nick $1-
      halt
    }
    if ($hiswm(find.fileserv,%txt)) {
      DLF.Win.Log Server $event @find $nick $1-
      halt
    }
    if ($hiswm(find.result,%txt)) {
      DLF.Watch.Log @find result: $1-
      if (%DLF.searchresults == 1) {
        DLF.Win.Log Filter $event @find $nick $1-
        DLF.@find.Results $1-
      }
      else DLF.Win.Log Server $event @find $nick $1-
      halt
    }
    if ((*Omen* iswm $strip($1)) && ($left($strip($2),1) == !)) {
      DLF.Watch.Log @find result: $2-
      if (%DLF.searchresults == 1) {
        DLF.Win.Log Filter $event @find $nick $1-
        DLF.@find.Results $2-
      }
      else DLF.Win.Log Server $event @find $nick $2-
      halt
    }
  }
}

alias -l DLF.@find.OnlyPartial {
  var %txt $strip($1-)
  if ($left(%txt,1) == !) return
  var %re $hfind(DLF.find.headregex,%txt,1,R).item
  if (%re == $null) return

  var %r $DLF.@find.Regex(%re,$hget(DLF.find.headregex,%re),%txt)
  if (%r == $null) return

  var %list $gettok(%r,1,$asc(:))
  var %found $gettok(%r,2,$asc(:))
  var %displayed $gettok(%r,3,$asc(:))
  var %search $gettok(%r,4,$asc(:))
  if (%found == %displayed) return
  DLF.Chan.SetNickColour
  if (%DLF.searchresults == 0) DLF.Win.Log Server $event @find $nick $1-
  else {
    var %r
    if (%search) %r = For $qt(%search)
    if (%found > 0) {
      if (%r == $null) %r = Found
      else %r = %r found
      %r = %r %found $+ , but
    }
    if (%r == $null) %r = First %displayed results displayed
    else %r = %r displaying only %displayed
    DLF.@find.Results %list %r $c(14,:: Double click here to get the server's full list)
  }
}

alias -l DLF.@find.Regex {
  if ($regex(DLF.@find.Regex,$3-,$1) !isnum 1-) return
  var %n $numtok($2,$asc($space))
  var %result
  while (%n) {
    var %i $gettok($2,%n,$asc($space))
    %result = : $+ %result
    if (%i > 0) %result = $regml(DLF.@find.Regex,%i) $+ %result
    else %result = 0 $+ %result
    dec %n
  }
  return %result
}

alias -l DLF.@find.Results {
  var %trig $strip($1)
  var %rest $2-
  if ($left(%trig,1) == !) {
    var %rest $strip(%rest)
    var %fn $DLF.GetFilename(%rest)
    var %len 0 - $len(%fn)
    dec %len
    %rest = $right(%rest,%len)
    if ($gettok(%rest,1,$asc($space)) == ::INFO::) {
      %rest = :: Size: $gettok(%rest,2-,$asc($space))
      var %left $pos(%rest,+,1) - 1
      if ($pos(%rest,+,0) > 0) $&
        %rest = $left(%rest,%left)
    }
    %rest = %fn $c(14,%rest)
  }
  var %msg %trig $tab $+ %rest
  if ((%trig != $+(!,$nick)) && (%trig != $+(@,$nick))) {
    %msg = %msg $c(4,0,:: Received from $nick)
  }
  var %win $+(@dlF.@find.,$network)
  if (!$window(%win)) window -lk0wn -t15 %win
  if ($line(%win,0) == 0) {
    aline -n 6 %win This window shows @find results as received individually from various servers.
    aline -n 2 %win In the future you might want to use @search instead of @find as it is quicker and more efficient.
    aline -n 2 %win If you use @search, consider installing the sbClient script to make processing @search results easier.
    aline -n 4 %win You can select lines and copy (Ctrl-C) and paste them (Ctrl-V) into the channel to get files,
    aline -n 4 %win or double-click to have the file request sent for you.
    aline -n 1 %win $crlf
  }
  var %i $line(%win,0)
  var %smsg $left(%msg,1)
  if (%smsg == !) %smsg = %smsg $+ $gettok(%msg,2-,$asc($tab))
  elseif (%smsg == @) %smsg = %msg
  else return
  while (%i) {
    var %l $line(%win,%i)
    if (%l == $crlf) break
    if ($left(%l,1) == !) %l = $left(%l,1) $+ $gettok(%l,2-,$asc($tab))
    if (%l == %smsg) DLF.Halt @find result: Result for %trig added to %win
    if (%l < %smsg) break
    dec %i
  }
  inc %i
  if ($left(%msg,1) == @) var %col 2
  else var %col 3
  iline -hn %col %win %i %msg
  window -b %win
  if ($timer($+($active,.Titlebar))) [ $+(.timer,$active,.Titlebar) ] off
  var %results $line(%win,0) - 6
  titlebar %win -=- %results @find results from $network so far -=- Right-click for options or double-click to download
  DLF.Halt @find result: Result for %trig added to %win
}

alias -l DLF.@find.Get {
  if ($1 < $DLF.Win.MinSelectLine) return
  var %line $replace($line($active,$1),$tab,$space)
  DLF.Watch.Called DLF.@find.Get %line
  var %trig $gettok(%line,1,$asc($space))
  var %type $left(%trig,1)
  if (%type !isin !@) return
  var %nick $right(%trig,-1)
  if (%type == @) var %fn
  else var %fn $DLF.GetFileName($gettok(%line,2-,$asc($space)))
  ; Find common channels for trigger nickname and issue the command in the channel
  var %i $comchan(%nick,0)
  while (%i) {
    var %chan $comchan(%nick,%i)
    if ($DLF.Chan.IsDlfChan(%chan)) {
      ; Use editbox not msg so other scripts (like sbClient) get On Input event
      DLF.Chan.EditSend %chan %trig %fn
      cline 7 $active $1
      return
    }
    dec %i
  }
}

alias -l DLF.@find.CopyLines {
  var %lines $sline($active,0)
  DLF.Watch.Called DLF.@find.CopyLines %lines
  if (!%lines) return
  DLF.@find.ResetColours
  clipboard
  var %i = 1, %c 0
  var %min $DLF.Win.MinSelectLine
  while (%i <= %lines) {
    var %ln $sline($active,%i).ln
    if (%ln >= %min) {
      clipboard -an $gettok($sline($active,%i),1,$asc($space)) $DLF.GetFileName($gettok($sline($active,%i),2-,$asc($space)))
      cline 7 $active %ln
      inc %c
    }
    inc %i
  }
  if ($timer($+($active,.Titlebar))) [ $+(.timer,$active,.Titlebar) ] 1 30 $timer($+($active,.Titlebar)).com
  else [ $+(.timer,$active,.Titlebar) ] 1 30 titlebar $active $window($active).title
  titlebar $active -=- %c line(s) copied to clipboard
}

alias -l DLF.@find.ResetColours {
  var %i $line($active,0)
  while (%i) {
    if ($line($active,%i) == $crlf) return
    if ($line($active,%i).color != 14) cline 3 $active %i
    dec %i
  }
}

alias -l DLF.@find.ColourNick {
  DLF.Watch.Called DLF.@find.ColourNick $1-
  var %win @dlF.@find. $+ $network
  if (!$window(%win)) return
  if ($comchan($1,0) == 0) {
    DLF.@find.DoColourLines $2 %win $nick $+(?,$nick, *)
    DLF.@find.DoColourLines $2 %win $nick $+(*:: Received from ,$nick)
  }
}

alias -l DLF.@find.DoColourLines {
  var %i $fline($2,$4-,0)
  if ((%i > 0) && ($event == join)) DLF.Chan.SetNickColour $3
  while (%i) {
    var %l $strip($fline($2,$4-,%i).text)
    if (%l == $crlf) return
    cline $1 $2 $fline($2,$4-,%i)
    dec %i
  }
}

; DLF.@find.ColourMe event chan
alias -l DLF.@find.ColourMe {
  var %win @dlF.@find. $+ $network
  if (!$window(%win)) return
  var %i $line(%win,0)
  DLF.Watch.Called DLF.@find.ColourMe %i lines
  while (%i) {
    var %l $strip($line(%win,%i))
    if (%l == $crlf) return
    dec %i
    var %nick = $right($gettok(%l,1,$asc($space)),-1), %c 14
    if ($1 == join) {
      DLF.Chan.SetNickColour %nick
      if ($nick($2,%nick) == $null) continue
      %c = 3
    }
    else {
      if ($comchan(%nick,0) > 1) continue
      if (($comchan(%nick,0) == 1) && ($nick($2,%nick) == $null)) continue
    }
    var %line %i + 1
    cline %c %win %line
  }
}

alias -l DLF.@find.SendToAutoGet {
  var %win $active
  var %lines $sline(%win,0)
  if (!%lines) halt
  DLF.Watch.Called DLF.@find.SendToAutoGet %lines files
  if ($fopen(MTlisttowaiting)) .fclose MTlisttowaiting
  .fopen MTlisttowaiting $+(",$remove($script(AutoGet.mrc),Autoget.mrc),AGwaiting.ini,")
  set %MTpath %MTdefaultfolder
  var %i 1
  var %j 0
  while (%i <= %lines) {
    var %temp $MTlisttowaiting($replace($sline(%win,%i),$nbsp,$space))
    var %j %j + $gettok(%temp,1,$asc($space))
    if ($sbClient.Online($sline($active,%i)) == 1) cline 10 $active $sline($active,%i).ln
    else cline 6 $active $sline($active,%i).ln
    inc %i
  }
  dec %i
  .fclose MTlisttowaiting
  unset %MTpath
  if (%MTautorequest == 1) MTkickstart $gettok(%temp,2,$asc($space))
  MTwhosinque
  echo -st %MTlogo Added %j File(s) To Waiting List From dlFilter
  titlebar %win -=- %j line(s) sent to AutoGet
}

alias -l DLF.@find.SendTovPowerGet {
  var %win $active
  var %lines $sline(%win,0)
  if (!%lines) halt
  DLF.Watch.Called DLF.@find.SendToAutoGet %lines files
  DLF.@find.ResetColours
  var %i 1
  while (%i <= %lines) {
    if ($com(vPG.NET,AddFiles,1,bstr,$sline(%win,%i)) == 0) {
      echo -st vPG.NET: AddFiles failed
    }
    cline 3 $active $sline($active,%i).ln
    inc %i
  }
  dec %i
  titlebar %win -=- %i line(s) sent to vPowerGet.NET
}

alias -l DLF.@find.SaveResults {
  var %fn $sfile($sysdir(downloads),Save @find results as a text file,Save)
  if (!%fn) return
  var %tok =
  %fn = $qt($deltok(%fn,-1,$asc(.)) $+ .txt)
  savebuf $active %fn
}

; ========== oNotice ==========
menu @#* {
  Clear: clear
  $iif(%DLF.win-onotice.timestamp == 1,$style(1)) Timestamp: DLF.Options.ToggleOption win-onotice.timestamp
  $iif(%DLF.win-onotice.log == 1,$style(1)) Logging: DLF.Options.ToggleOption win-onotice.log
  Options: DLF.Options.Show
  -
  Close: DLF.oNotice.Close $active
  -
}

alias -l DLF.oNotice.Input {
  var %chan $right($active,-1)
  DLF.Watch.Called DLF.oNotice.Input %chan $1-
  if ($gettok(%chan,-1,$asc(.)) == $network) %chan = $deltok(%chan,-1,$asc(.))
  var %omsg $1-
  var %event Text
  if (($left($1,1) == /) && ($ctrlenter == $false) && ($1 !isin /me /say)) return
  if (($left($1,1) == /) && ($ctrlenter == $false)) {
    if ($1 == /me) %event = Action
    %omsg = $2-
  }
  if ($me isop %chan) {
    if ((@ isin $DLF.iSupport.Supports(STATUSMSG)) || ($DLF.iSupport.Supports(WALLCHOPS))) {
      ; FUTURE - switch to msg once this version has reasonable penetration
      if (%event == Text) .notice @ $+ %chan $1-
      else .describe @ $+ %chan $2-
    }
    elseif (%event == Text) .onotice %chan $1-
    else .onotice %chan /me $2-
    DLF.oNotice.Log %event $active $me %omsg
    DLF.Win.Echo %event $active $me %omsg
  }
  else {
    var %ts
    if (%DLF.win-onotice.timestamp) %ts = $timestamp
    echo 4 $active %ts $DLF.Logo oNotice not sent: You are no longer an op in %ochan
  }
  halt
}

alias -l DLF.oNotice.Channel {
  if (%DLF.win-onotice.enabled != 1) return
  DLF.Watch.Called DLF.oNotice.Channel $1-
  var %win $DLF.oNotice.Open(0)
  var %omsg $1-
  var %event $event
  if ((%event != action) && ($gettok(%omsg,1,$asc($space)) == /me)) {
    %event = action
    %omsg = $2-
  }
  elseif ($1 == @) var %omsg $2-
  if (%event == notice) %event = Text
  DLF.Win.Echo %event %win $nick %omsg
  DLF.oNotice.Log %event %win $nick %omsg
  DLF.Halt oNotice sent to %win
}

alias -l DLF.oNotice.IsoNotice {
  if (%DLF.win-onotice.enabled != 1) return $false
  if ($target != @ $+ $chan) return $false
  if ($me !isop $chan) return $false
  if ($nick !isop $chan) return $false
  DLF.Watch.Log Is oNotice
  return $true
}

alias -l DLF.oNotice.Open {
  if (%DLF.win-onotice.enabled != 1) return
  if ($me !isop $chan) return
  var %chan $+(@,$chan)
  var %win $+(%chan,.,$network)
  if ($window(%win)) {
    window -a %win
    return %win
  }
  DLF.Watch.Called DLF.oNotice.Open
  DLF.oNotice.Log Session %win $me ----- Session started -----
  var %flags -el12mS
  if ($1 == 0) %flags = -el12mSn
  window %flags %win
  var %log $DLF.oNotice.LogFile(%chan)
  if ((%DLF.win-onotice.log == 1) && ($isfile(%log))) .loadbuf $windowbuffer -rpi %win %log
  titlebar %win -=- Chat window for ops in $chan on $network
  DLF.oNotice.AddChanNicks
  return %win
}

alias -l DLF.oNotice.Close {
  DLF.oNotice.Log Session $1 $me ----- Session closed -----
  close -@ $1
}

alias -l DLF.oNotice.Log {
  if (%DLF.win-onotice.log == 1) {
    var %line $DLF.Win.Format($1-)
    var %log $DLF.oNotice.LogFile($2)
    write -m1 %log $logstamp %line
  }
}

alias -l DLF.oNotice.LogFile {
  var %chan $1
  if ($gettok(%chan,-1,$asc(.)) == $network) %chan = $deltok(%chan,-1,$asc(.))
  return $+($logdir,$mklogfn(%chan))
}

alias -l DLF.oNotice.AddChanNicks {
  if (%DLF.win-onotice.enabled != 1) return
  DLF.Watch.Called DLF.oNotice.AddChanNicks $chan
  var %win $+(@,$chan,.,$network)
  if (!$window(%win)) return
  var %i $nick($chan,0,o)
  while (%i) {
    DLF.oNotice.AddNick $nick($chan,%i,o)
    dec %i
  }
}

alias -l DLF.oNotice.AddNick {
  if (%DLF.win-onotice.enabled != 1) return
  if ($1 != $null) var %nick $1
  elseif ($event isin op deop) var %nick $opnick
  else var %nick $nick
  if ($1 == $null) DLF.Watch.Called DLF.oNotice.AddNick $event %nick in $chan
  var %win $+(@,$chan,.,$network)
  if (!$window(%win)) return
  aline -nl $DLF.Chan.NickColour($nick($chan,%nick).pnick) %win $DLF.Chan.PrefixedNick($chan,%nick)
  window -S %win
  DLF.Watch.Log oNotice: Added %nick to oplist in %win
}

alias -l DLF.oNotice.DelNick {
  if (%DLF.win-onotice.enabled != 1) return
  var %nick $nick
  if ($event isin op deop) %nick = $opnick
  elseif ($event isin kick) %nick = $knick
  if ($1 != $null) var %chan $1
  else var %chan $chan
  var %win $+(@,%chan,.,$network)
  if ($1 == $null) DLF.Watch.Called DLF.oNotice.DelNick $event %nick %chan
  if (!$window(%win)) return
  if (%nick == $me) {
    clear -l %win
    DLF.Watch.Log oNotice: Cleared oplist in %win
    return
  }
  var %match * $+ %nick
  var %i $fline(%win,%match,0,1)
  while (%i) {
    var %l $fline(%win,%match,%i,1)
    var %opnick $line(%win,%l,1)
    while ($left(%opnick,1) isin $prefix) %opnick = $right(%opnick,-1)
    if (%opnick == %nick) {
      dline -l %win %l
      DLF.Watch.Log oNotice: Removed %nick from oplist in %win
      return
    }
    dec %i
  }
}

alias -l DLF.oNotice.DelNickAllChans {
  if (%DLF.win-onotice.enabled != 1) return
  if ($event isin op deop) var %nick $opnick
  else var %nick $nick
  DLF.Watch.Called DLF.oNotice.DelNickAllChans %nick
  var %match $+(@#*.,$network)
  var %i $window(%match,0)
  while (%i) {
    var %win $window(%match,%i)
    if ($cid == $window(%win).cid) {
      var %chan $right($deltok(%win,-1,$asc(.)),-1)
      if (%nick == $me) clear -l %win
      else DLF.oNotice.DelNick %chan
    }
    dec %i
  }
}

alias -l DLF.oNotice.NickChg {
  if (%DLF.win-onotice.enabled != 1) return
  DLF.Watch.Called DLF.oNotice.Channel $nick => $newnick
  var %match $+(@#*.,$network)
  var %i $window(%match,0)
  while (%i) {
    var %win $window(%match,%i)
    if ($cid == $window(%win).cid) {
      var %chan $right($deltok(%win,-1,$asc(.)),-1)
      var %nickmatch * $+ $nick
      var %j $fline(%win,%nickmatch,0,1)
      while (%j) {
        var %l $fline(%win,%nickmatch,%j,1)
        var %nick $line(%win,%l,1)
        while ($left(%nick,1) isin $prefix) %nick = $right(%nick,-1)
        if (%nick == $nick) {
          rline -l $line(%win,%l,1).color %win %l $replace($line(%win,%l,1),$nick,$newnick)
          DLF.Win.Echo Nick %win $nick $1-
          DLF.Watch.Log oNotice: Renamed $nick to $newnick in oplist in %win
          break
        }
        dec %j
      }
      window -S %win
    }
    dec %i
  }
}

; ========== mIRC security check - future functionality ==========
; IRC / Catcher / Chat links; Confirm requests checked.
; IRC / Flood / Flood protection on (plus optimum settings?)
; IRC / Flood / What is being limited?
; IRC / Flood / Queue own messages?
; IRC / Sounds / Requests / Accept sound requests? not set
; IRC / Sounds / Requests / Listen for !nick file not set
; DCC / On Send / Trusted / Limit Auto-Get to trusted users set
; Other / Enable Sendmessage Server
; Other / Confirm / Command that may run a script


; ========== Options Dialog ==========
alias DLF.Options.Show dialog $iif($dialog(DLF.Options.GUI),-v,-md) DLF.Options.GUI DLF.Options.GUI
alias DLF.Options.Toggle dialog $iif($dialog(DLF.Options.GUI),-c,-md) DLF.Options.GUI DLF.Options.GUI

dialog -l DLF.Options.GUI {
  title dlFilter v $+ $DLF.SetVersion
  size -1 -1 168 218
  option dbu notheme
  text "", 20, 67 2 98 7, right hide
  check "&Enable/disable dlFilter", 10, 2 2 62 8
  tab "Channels", 1, 1 9 166 193
  tab "Filters", 3
  tab "Other", 5
  tab "Ops", 7
  tab "Custom", 8
  tab "About", 9
  check "Show/hide Filter wins", 30, 1 205 60 11, push
  check "Show/hide Ads wins", 40, 65 205 60 11, push
  button "Close", 50, 129 205 37 11, ok default flat
  ; tab Channels
  text "List the channels you want dlFilter to filter messages in. Use # by itself to make it filter all channels on all networks.", 105, 5 25 160 12, tab 1 multi
  text "Channel to add (select dropdown / type #chan or net#chan):", 110, 5 40 160 7, tab 1
  combo 120, 4 48 160 6, tab 1 drop edit
  button "Add", 130, 5 61 76 11, tab 1 flat disable
  button "Remove", 135, 86 61 76 11, tab 1 flat disable
  list 140, 4 74 160 83, tab 1 vsbar size sort extsel
  box " Update ", 150, 4 158 160 41, tab 1
  text "Checking for dlFilter updates…", 160, 7 166 135 8, tab 1
  button "dlFilter website", 170, 7 175 74 11, tab 1 flat
  button "Update dlFilter", 180, 86 175 74 11, tab 1 flat disable
  check "Check for &beta versions", 190, 7 189 136 6, tab 1
  ; tab Filters
  box " General ", 305, 4 23 160 118, tab 3
  check "Filter other users Search / File requests", 310, 7 32 155 6, tab 3
  check "Filter adverts and announcements", 315, 7 41 155 6, tab 3
  check "Filter channel mode changes (e.g. user limits)", 325, 7 50 155 6, tab 3
  check "Filter channel spam", 330, 7 59 155 6, tab 3
  check "Filter private spam", 335, 7 68 155 6, tab 3
  check "… and /ignore spammer for 1h (asks confirmation)", 340, 15 77 147 6, tab 3
  check "Filter channel messages with control codes (usually a bot)", 345, 7 86 155 6, tab 3
  check "Filter channel topic messages", 350, 7 95 155 6, tab 3
  check "Filter server responses to my requests to separate window", 355, 7 104 155 6, tab 3
  check "Filter requests to you in PM (@yournick, !yournick)", 360, 7 113 155 6, tab 3
  check "Separate dlF windows per connection", 365, 7 122 155 6, tab 3
  check "Keep Filter and Ads windows active in background", 370, 7 131 155 6, tab 3
  box " Filter user events ", 375, 4 142 160 57, tab 3
  check "Joins …", 380, 7 152 53 6, tab 3
  check "Parts …", 382, 66 152 53 6, tab 3
  check "Quits …", 384, 120 152 53 6, tab 3
  check "Nick changes …", 386, 7 161 53 6, tab 3
  check "Kicks …", 388, 66 161 53 6, tab 3
  check "Away and thank-you messages", 390, 7 170 155 6, tab 3
  check "User mode changes", 395, 7 179 155 6, tab 3
  check "Filter user events only for regular users", 397, 7 188 155 6, tab 3
  ; Tab Other
  box " Extra functions ", 505, 4 23 160 37, tab 5
  check "Collect @find/@locator results into a single window", 510, 7 32 155 6, tab 5
  check "Display dlFilter channel efficiency in title bar", 525, 7 41 155 6, tab 5
  check "Colour uncoloured fileservers in nickname list", 530, 7 50 155 6, tab 5
  box " File requests ", 535, 4 61 160 73, tab 5
  check "Auto accept files you have specifically requested", 540, 7 70 155 6, tab 5
  check "Block ALL files you have NOT specifically requested. Or:", 545, 7 79 155 6, tab 5
  check "Block potentially dangerous filetypes", 550, 15 88 147 6, tab 5
  check "Block files from users not in a common channel", 555, 15 97 147 6, tab 5
  check "Block files from users not in your mIRC DCC trust list", 560, 15 106 147 6, tab 5
  check "Block files from regular users", 565, 15 115 147 6, tab 5
  check "Retry incomplete file requests (up to 3 times)", 570, 7 124 155 6, tab 5
  box " mIRC-wide ", 605, 4 135 160 64, tab 5
  check "Check mIRC settings are secure (future enhancement)", 610, 7 144 155 6, tab 5 disable
  check "Allow private messages from users with open query window", 615, 7 153 155 6, tab 5
  check "Block private messages from users not in a common channel", 620, 7 162 155 6, tab 5
  check "Block private messages from regular users", 625, 7 171 155 6, tab 5
  check "Block channel CTCP requests unless from an op", 655, 7 180 155 6, tab 5
  check "Block IRC Finger requests (which share personal information)", 660, 7 189 155 6, tab 5
  ; tab Ops
  text "These options are only enabled if you are an op on a filtered channel.", 705, 4 25 160 12, tab 7 multi
  box " Channel Ops ", 710, 4 38 160 38, tab 7
  check "Filter oNotices to separate @#window (OpsTalk)", 715, 7 48 155 6, tab 7
  check "On channel spam, oNotify if you are an op", 725, 7 57 155 6, tab 7
  check "On private spam, oNotify if you are op in a common channel", 730, 7 66 155 6, tab 7
  box " dlFilter promotion ", 755, 4 77 160 38, tab 7
  check "Advertise dlFilter in channels every", 760, 7 87 93 6, tab 7
  edit "60", 765, 101 85 12 10, tab 7 right limit 2
  text "mins", 770, 115 86 47 7, tab 7
  check "… and filter them out", 780, 15 96 147 6, tab 7
  check "Prompt individual existing dlFilter users to upgrade", 790, 7 105 155 6, tab 7
  ; tab Custom
  check "Enable custom filters", 810, 5 27 65 7, tab 8
  text "Message type:", 820, 74 27 50 7, tab 8
  combo 830, 114 25 50 10, tab 8 drop
  edit "", 840, 4 37 160 10, tab 8 autohs
  button "Add", 850, 5 51 76 11, tab 8 flat disable
  button "Remove", 860, 86 51 76 11, tab 8 flat disable
  list 870, 4 64 160 135, tab 8 hsbar vsbar size sort extsel
  ; tab About
  edit "", 920, 3 25 162 158, multi read vsbar tab 9
  text "Download:", 980, 5 185 35 7, tab 9
  link "https://github.com/DukeLupus/dlFilter/", 985, 45 185 120 7, tab 9
  text "Report issues:", 990, 5 192 35 7, tab 9
  link "https://gitreports.com/issue/DukeLupus/dlFilter/", 995, 45 192 120 7, tab 9
}

alias -l DLF.Options.SetLinkedFields {
  DLF.Options.LinkedFields 335 340
  DLF.Options.LinkedFields -545 550,555,560,565
}

; Initialise dialog
on *:dialog:DLF.Options.GUI:init:0: DLF.Options.Init
; Channel text box typed or clicked - Enable / disable Add channel button
on *:dialog:DLF.Options.GUI:edit:120: DLF.Options.SetAddChannelButton
on *:dialog:DLF.Options.GUI:sclick:120: DLF.Options.SetAddChannelButton
; Channel Add button clicked
on *:dialog:DLF.Options.GUI:sclick:130: DLF.Options.AddChannel
; Channel Remove button clicked
on *:dialog:DLF.Options.GUI:sclick:135: DLF.Options.RemoveChannel
; Channel list clicked - Enable / disable Remove channel button
on *:dialog:DLF.Options.GUI:sclick:140: DLF.Options.SetRemoveChannelButton
; Channel list double click - Remove channel and put in text box for editing and re-adding.
on *:dialog:DLF.Options.GUI:dclick:140: DLF.Options.EditChannel
; Goto website button
on *:dialog:DLF.Options.GUI:sclick:170: url -a https://github.com/DukeLupus/dlFilter/
; Download update button
on *:dialog:DLF.Options.GUI:sclick:180: DLF.Options.DownloadUpdate
; Per-Server option clicked
on *:dialog:DLF.Options.GUI:sclick:365: DLF.Options.PerConnection
; Background Ads / Filter option clicked
on *:dialog:DLF.Options.GUI:sclick:365: DLF.Options.Background
; Titlebar option clicked
on *:dialog:DLF.Options.GUI:sclick:525: DLF.Options.Titlebar
; oNotice option clicked
on *:dialog:DLF.Options.GUI:sclick:715: DLF.Options.oNotice
; Advertising period changed
on *:dialog:DLF.Options.GUI:edit:765: DLF.Options.OpsAdPeriod
; Select custom message type
on *:dialog:DLF.Options.GUI:sclick:830: DLF.Options.SetCustomType
; Enable / disable Add custom message button
on *:dialog:DLF.Options.GUI:edit:840: DLF.Options.SetAddCustomButton
; Customer filter Add button clicked
on *:dialog:DLF.Options.GUI:sclick:850: DLF.Options.AddCustom
; Customer filter Remove button clicked or double click in list
on *:dialog:DLF.Options.GUI:sclick:860: DLF.Options.RemoveCustom
; Enable / disable Remove custom message button
on *:dialog:DLF.Options.GUI:sclick:870: DLF.Options.SetRemoveCustomButton
; Double click on custom text line removes line but puts it into Add box for editing and re-adding.
on *:dialog:DLF.Options.GUI:dclick:870: DLF.Options.EditCustom
; Handle all other checkbox clicks and save
; Should go last so that sclick for specific fields take precedence
on *:dialog:DLF.Options.GUI:sclick:10-999: DLF.Options.ClickOption

; Initialise variables
alias -l DLF.Options.Initialise {
  ; Options Dialog variables in display order

  ; All tabs
  DLF.Options.InitOption enabled 1
  DLF.Options.InitOption showfiltered = 1

  ; Channels tab
  if (%DLF.netchans == $null) {
    DLF.Chan.Set $hashtag
    DLF.StatusAll Channels set to $c(4,all) $+ .
  }
  else DLF.Chan.Set %DLF.netchans

  ; Channels tab - Check for updates
  DLF.Options.InitOption update.betas 0

  ; Filter tab
  ; Filter tab General box
  DLF.Options.InitOption filter.requests 1
  DLF.Options.InitOption filter.ads 1
  DLF.Options.InitOption serverads 1
  DLF.Options.InitOption filter.modeschan 1
  DLF.Options.InitOption filter.spamchan 1
  DLF.Options.InitOption filter.spampriv 1
  DLF.Options.InitOption spam.addignore 0
  DLF.Options.InitOption filter.controlcodes 0
  DLF.Options.InitOption filter.topic 0
  DLF.Options.InitOption serverwin 0
  DLF.Options.InitOption private.requests 1
  DLF.Options.InitOption perconnect 1
  DLF.Options.InitOption background 0
  ; Filter tab User events box
  DLF.Options.InitOption filter.joins 1
  DLF.Options.InitOption filter.parts 1
  DLF.Options.InitOption filter.quits 1
  DLF.Options.InitOption filter.nicks 1
  DLF.Options.InitOption filter.kicks 1
  DLF.Options.InitOption filter.aways 1
  DLF.Options.InitOption filter.modesuser 1
  DLF.Options.InitOption filter.regular 0

  ; Other tab
  ; Other tab Extra Functions box
  DLF.Options.InitOption searchresults 1
  DLF.Options.InitOption titlebar.stats 1
  DLF.Options.InitOption colornicks 1
  ; Other tab File requests box
  DLF.Options.InitOption dccsend.autoaccept 1
  DLF.Options.InitOption dccsend.requested 1
  DLF.Options.InitOption dccsend.dangerous 1
  DLF.Options.InitOption dccsend.nocomchan 1
  DLF.Options.InitOption dccsend.untrusted 1
  DLF.Options.InitOption dccsend.regular 1
  DLF.Options.InitOption serverretry 1
  ; Other tab mIRC-wide box
  DLF.Options.InitOption checksecurity 1
  DLF.Options.InitOption private.query 1
  DLF.Options.InitOption private.nocomchan 1
  DLF.Options.InitOption private.regular 1
  DLF.Options.InitOption chanctcp 1
  DLF.Options.InitOption nofingers 1

  ; Ops tab
  DLF.Options.InitOption win-onotice.enabled 1
  DLF.Options.InitOption opwarning.spamchan 1
  DLF.Options.InitOption opwarning.spampriv 1
  DLF.Options.InitOption ops.advertchan 0
  DLF.Options.InitOption ops.advertchan.filter 0
  DLF.Options.InitOption ops.advertpriv 0

  ; Custom tab
  DLF.Options.InitOption custom.enabled 1
  DLF.Options.InitOption custom.chantext $addtok(%DLF.custom.chantext,$replace(*this is an example custom filter*,$space,$nbsp),$asc($comma))

  ; Options only available in menu not options
  ; TODO Consider adding these as options
  DLF.Options.InitOption win-filter.log 0
  DLF.Options.InitOption win-filter.timestamp 1
  DLF.Options.InitOption win-filter.wrap 1
  DLF.Options.InitOption win-filter.strip 0
  DLF.Options.InitOption win-server.log 0
  DLF.Options.InitOption win-server.timestamp 1
  DLF.Options.InitOption win-server.wrap 1
  DLF.Options.InitOption win-server.strip 0
  DLF.Options.InitOption win-onotice.timestamp 1
  DLF.Options.InitOption win-onotice.log 1
}

alias -l DLF.Options.InitOption {
  var %var $+(%,DLF.,$1)
  if ( [ [ %var ] ] != $null) return
  [ [ %var ] ] = $2
  if (%DLF.JustLoaded) set -u1 %DLF.OptionInit $true
}

alias -l DLF.Options.ToggleShowFilter {
  DLF.Options.ToggleOption showfiltered 30
  DLF.Options.SetButtonTextFilter
  DLF.Win.ShowHide @dlF.Filter* %DLF.showfiltered
}

alias -l DLF.Options.ToggleShowAds {
  DLF.Options.ToggleOption serverads 40
  DLF.Options.SetButtonTextAds
  DLF.Win.ShowHide @dlF.Ads.* %DLF.serverads
}

alias -l DLF.Options.SetButtonTextFilter { DLF.Options.SetButtonText 30 Filter windows }
alias -l DLF.Options.SetButtonTextAds { DLF.Options.SetButtonText 40 Ads windows }
alias -l DLF.Options.SetButtonText {
  if (!$dialog(DLF.Options.GUI)) return
  if ($did(DLF.Options.GUI,$1).state) did -a DLF.Options.GUI $1 Hide $2-
  else did -a DLF.Options.GUI $1 Show $2-
}

alias -l DLF.Options.ToggleOption {
  var %var $+(%,DLF.,$1)
  if ([ [ %var ] ]) var %newval 0
  else var %newval 1
  [ [ %var ] ] = %newval
  if (($2 != $null) && ($dialog(DLF.Options.GUI))) {
    if (%newval) did -c DLF.Options.GUI $2
    else did -u DLF.Options.GUI $2
  }
}

alias -l DLF.Options.Init {
  ; Disable Ops tab
  DLF.Options.OpsTab

  ; Disable enabling and show msg if mIRC version too low
  var %ver $DLF.mIRCversion
  if (%ver != 0) {
    did -b DLF.Options.GUI 10
    did -vo DLF.Options.GUI 20 1 Upgrade to %ver $+ +
  }
  if (%DLF.enabled == 1) did -c DLF.Options.GUI 10
  if (%DLF.showfiltered == 1) did -c DLF.Options.GUI 30
  DLF.Options.SetButtonTextFilter
  if (%DLF.serverads == 1) did -c DLF.Options.GUI 40
  DLF.Options.SetButtonTextAds
  if (%DLF.update.betas == 1) did -c DLF.Options.GUI 190
  if (%DLF.filter.requests == 1) did -c DLF.Options.GUI 310
  if (%DLF.filter.ads == 1) did -c DLF.Options.GUI 315
  if (%DLF.filter.modeschan == 1) did -c DLF.Options.GUI 325
  if (%DLF.filter.spamchan == 1) did -c DLF.Options.GUI 330
  if (%DLF.filter.spampriv == 1) did -c DLF.Options.GUI 335
  else %DLF.spam.addignore = 0
  if (%DLF.spam.addignore == 1) did -c DLF.Options.GUI 340
  if (%DLF.filter.controlcodes == 1) did -c DLF.Options.GUI 345
  if (%DLF.filter.topic == 1) did -c DLF.Options.GUI 350
  if (%DLF.serverwin == 1) did -c DLF.Options.GUI 355
  if (%DLF.private.requests == 1) did -c DLF.Options.GUI 360
  if (%DLF.perconnect == 1) did -c DLF.Options.GUI 365
  if (%DLF.background == 1) did -c DLF.Options.GUI 370
  if (%DLF.filter.joins == 1) did -c DLF.Options.GUI 380
  if (%DLF.filter.parts == 1) did -c DLF.Options.GUI 382
  if (%DLF.filter.quits == 1) did -c DLF.Options.GUI 384
  if (%DLF.filter.nicks == 1) did -c DLF.Options.GUI 386
  if (%DLF.filter.kicks == 1) did -c DLF.Options.GUI 388
  if (%DLF.filter.aways == 1) did -c DLF.Options.GUI 390
  if (%DLF.filter.modesuser == 1) did -c DLF.Options.GUI 395
  if (%DLF.filter.regular == 1) did -c DLF.Options.GUI 397
  if (%DLF.searchresults == 1) did -c DLF.Options.GUI 510
  if (%DLF.titlebar.stats == 1) did -c DLF.Options.GUI 525
  if (%DLF.colornicks == 1) did -c DLF.Options.GUI 530
  if (%DLF.dccsend.autoaccept == 1) did -c DLF.Options.GUI 540
  if (%DLF.dccsend.requested == 1) {
    did -c DLF.Options.GUI 545
    %DLF.dccsend.dangerous = 1
    %DLF.dccsend.nocomchan = 1
    %DLF.dccsend.untrusted = 1
    %DLF.dccsend.regular = 1
  }
  if (%DLF.dccsend.dangerous == 1) did -c DLF.Options.GUI 550
  if (%DLF.dccsend.nocomchan == 1) did -c DLF.Options.GUI 555
  if (%DLF.dccsend.untrusted == 1) did -c DLF.Options.GUI 560
  if (%DLF.dccsend.regular == 1) did -c DLF.Options.GUI 565
  if (%DLF.serverretry == 1) did -c DLF.Options.GUI 570
  if (%DLF.checksecurity == 1) did -c DLF.Options.GUI 610
  if (%DLF.private.query == 1) did -c DLF.Options.GUI 615
  if (%DLF.private.nocomchan == 1) did -c DLF.Options.GUI 620
  if (%DLF.private.regular == 1) did -c DLF.Options.GUI 625
  if (%DLF.chanctcp == 1) did -c DLF.Options.GUI 655
  if (%DLF.nofingers == 1) did -c DLF.Options.GUI 660
  if (%DLF.win-onotice.enabled == 1) did -c DLF.Options.GUI 715
  if (%DLF.opwarning.spamchan == 1) did -c DLF.Options.GUI 725
  if (%DLF.opwarning.spampriv == 1) did -c DLF.Options.GUI 730
  if (%DLF.ops.advertchan == 1) did -c DLF.Options.GUI 760
  did -ra DLF.Options.GUI 765 %DLF.ops.advertchan.period
  if (%DLF.ops.advertchan.filter == 1) did -c DLF.Options.GUI 780
  if (%DLF.ops.advertpriv == 1) did -c DLF.Options.GUI 790
  if (%DLF.custom.enabled == 1) did -c DLF.Options.GUI 810
  DLF.Options.InitChannelList
  DLF.Options.InitCustomList
  DLF.Options.SetLinkedFields
  DLF.Update.Run
  DLF.Options.About
}

alias -l DLF.Options.LinkedFields {
  var %state $did(DLF.Options.GUI,$abs($1)).state
  if ($1 < 0) %state = 1 - %state
  if (%state) var %flags -e
  else var %flags -cb
  did %flags DLF.Options.GUI $2
}

alias -l DLF.Options.Save {
  DLF.Chan.Set %DLF.netchans
  %DLF.enabled = $did(DLF.Options.GUI,10).state
  DLF.Groups.Events
  %DLF.showfiltered = $did(DLF.Options.GUI,30).state
  %DLF.update.betas = $did(DLF.Options.GUI,190).state
  %DLF.filter.requests = $did(DLF.Options.GUI,310).state
  %DLF.filter.ads = $did(DLF.Options.GUI,315).state
  %DLF.serverads = $did(DLF.Options.GUI,40).state
  %DLF.filter.modeschan = $did(DLF.Options.GUI,325).state
  %DLF.filter.spamchan = $did(DLF.Options.GUI,330).state
  %DLF.filter.spampriv = $did(DLF.Options.GUI,335).state
  %DLF.spam.addignore = $did(DLF.Options.GUI,340).state
  %DLF.filter.controlcodes = $did(DLF.Options.GUI,345).state
  %DLF.filter.topic = $did(DLF.Options.GUI,350).state
  %DLF.serverwin = $did(DLF.Options.GUI,355).state
  %DLF.private.requests = $did(DLF.Options.GUI,360).state
  %DLF.perconnect = $did(DLF.Options.GUI,365).state
  %DLF.background = $did(DLF.Options.GUI,370).state
  %DLF.filter.joins = $did(DLF.Options.GUI,380).state
  %DLF.filter.parts = $did(DLF.Options.GUI,382).state
  %DLF.filter.quits = $did(DLF.Options.GUI,384).state
  %DLF.filter.nicks = $did(DLF.Options.GUI,386).state
  %DLF.filter.kicks = $did(DLF.Options.GUI,388).state
  %DLF.filter.aways = $did(DLF.Options.GUI,390).state
  %DLF.filter.modesuser = $did(DLF.Options.GUI,395).state
  %DLF.filter.regular = $did(DLF.Options.GUI,397).state
  %DLF.searchresults = $did(DLF.Options.GUI,510).state
  %DLF.titlebar.stats = $did(DLF.Options.GUI,525).state
  %DLF.colornicks = $did(DLF.Options.GUI,530).state
  %DLF.dccsend.autoaccept = $did(DLF.Options.GUI,540).state
  %DLF.dccsend.requested = $did(DLF.Options.GUI,545).state
  %DLF.dccsend.dangerous = $did(DLF.Options.GUI,550).state
  %DLF.dccsend.nocomchan = $did(DLF.Options.GUI,555).state
  %DLF.dccsend.untrusted = $did(DLF.Options.GUI,560).state
  %DLF.dccsend.regular = $did(DLF.Options.GUI,565).state
  %DLF.serverretry = $did(DLF.Options.GUI,570).state
  %DLF.checksecurity = $did(DLF.Options.GUI,610).state
  %DLF.private.query = $did(DLF.Options.GUI,615).state
  %DLF.private.nocomchan = $did(DLF.Options.GUI,620).state
  %DLF.private.regular = $did(DLF.Options.GUI,625).state
  %DLF.chanctcp = $did(DLF.Options.GUI,655).state
  %DLF.nofingers = $did(DLF.Options.GUI,660).state
  %DLF.win-onotice.enabled = $did(DLF.Options.GUI,715).state
  %DLF.opwarning.spamchan = $did(DLF.Options.GUI,725).state
  %DLF.opwarning.spampriv = $did(DLF.Options.GUI,730).state
  %DLF.ops.advertchan = $did(DLF.Options.GUI,760).state
  %DLF.ops.advertchan.period = $did(DLF.Options.GUI,765)
  if (%DLF.ops.advertchan.period == $null) %DLF.ops.advertchan.period = 5
  elseif (%DLF.ops.advertchan.period == 0) %DLF.ops.advertchan.period = 1
  %DLF.ops.advertchan.filter = $did(DLF.Options.GUI,780).state
  %DLF.ops.advertpriv = $did(DLF.Options.GUI,790).state
  DLF.Ops.AdvertsEnable
  %DLF.custom.enabled = $did(DLF.Options.GUI,810).state
  saveini
  DLF.Options.SetLinkedFields
}

alias -l DLF.Options.OpsTab {
  ; Disable Ops Tab if all ops options are off and not ops in any dlF channels
  if ($DLF.Options.IsOp) var %flags -e
  else var %flags -b
  did %flags DLF.Options.GUI 715,725,730,760,765,770,780,790
  if (%DLF.netchans == $hashtag) did -b DLF.Options.GUI 760,765,770,780,790
}

alias -l DLF.Options.IsOp {
  var %i $Scon(0)
  while (%i) {
    scon %i
    var %j $chan(0)
    while (%j) {
      if ($me isop $chan(%j)) {
        scon -r
        return $true
      }
      dec %j
    }
    dec %i
  }
  scon -r
  return $false
}

alias -l DLF.Options.PerConnection {
  DLF.Options.Save
  DLF.Stats.Active
  close -a@ @dlF.Filter*
  close -a@ @dlF.Server*
  close -a@ @dlF.Ads.*
}

alias -l DLF.Options.Background {
  DLF.Options.Save
  if (%DLF.background == 1) return
  if (%DLF.showfiltered == 0) close -a@ @dlF.Filter*
  if (%DLF.serverads == 0) close -a@ @dlF.Ads.*
}

alias -l DLF.Options.Titlebar {
  DLF.Options.Save
  DLF.Stats.Active
}

alias -l DLF.Options.OpsAdPeriod {
  var %period $did(DLF.Options.GUI,765)
  if (%period !isnum 1-99) {
    %period = $regsubex(DLF.Options.OpsAdPeriod,%period,/([^0-9]+)/g,$null)
    did -ra DLF.Options.GUI 765 %period
    return
  }
  DLF.Options.Save
}

alias -l DLF.Options.oNotice {
  DLF.Options.Save
  close -a@ @#*
}

alias -l DLF.Options.ClickOption {
  DLF.Options.Save
  DLF.Options.SetButtonTextFilter
  DLF.Options.SetButtonTextAds
  DLF.Win.ShowHide @dlF.Filter* %DLF.showfiltered
  DLF.Win.ShowHide @dlF.Ads.* %DLF.serverads
  if (($did == 190) && (!$sock(DLF.Socket.Update))) DLF.Update.CheckVersions
}

alias -l DLF.Options.InitChannelList {
  ; List connected networks and channels
  var %i $scon(0)
  var %nets
  var %netchans
  while (%i) {
    scon %i
    %nets = $addtok(%nets,$network,$asc($space))
    var %j $chan(0)
    while (%j) {
      %netchans = $addtok(%netchans,$+($network,$chan(%j)),$asc($space))
      dec %j
    }
    dec %i
  }
  scon -r
  %netchans = $sorttok(%netchans,$asc($space))

  ; Add networks in filtered channel list
  var %i $numtok(%DLF.netchans,$asc($comma))
  while (%i) {
    var %netchan $gettok(%DLF.netchans,%i,$asc($comma))
    if ($left(%netchan,1) == $hashtag) var %net
    else var %net $gettok(%netchan,1,$asc($hashtag))
    if (%net) %nets = $addtok(%nets,%net,$asc($space))
    dec %i
  }
  if ($numtok(%nets,$asc($space)) <= 1) var %onenet $true
  else var %onenet $false

  ; Populate dropdown of possible channels to add
  did -r DLF.Options.GUI 120
  DLF.Options.SetAddChannelButton
  var %numchans = $numtok(%netchans,$asc($space)), %i 1
  while (%i <= %numchans) {
    var %netchan $gettok(%netchans,%i,$asc($space))
    if ($istok(%DLF.netchans,%netchan,$asc($comma)) == $false) {
      if (%onenet) %netchan = $+($hashtag,$gettok(%netchan,2,$asc($hashtag)))
      did -a DLF.Options.GUI 120 %netchan
    }
    inc %i
  }

  ; Populate list of filtered channels
  did -r DLF.Options.GUI 140
  var %numchans = $numtok(%DLF.netchans,$asc($comma)), %i 1
  while (%i <= %numchans) {
    var %netchan $gettok(%DLF.netchans,%i,$asc($comma))
    if ($left(%netchan,1) !isalpha) var %chan %netchan
    elseif (%onenet) var %chan $+($hashtag,$gettok(%netchan,2,$asc($hashtag)))
    else var %chan %netchan
    did -a DLF.Options.GUI 140 %chan
    inc %i
  }
}

alias -l DLF.Options.SetAddChannelButton {
  if ($did(DLF.Options.GUI,120)) did -te DLF.Options.GUI 130
  else {
    did -b DLF.Options.GUI 130
    did -t DLF.Options.GUI 50
  }
}

alias -l DLF.Options.SetRemoveChannelButton {
  if ($did(DLF.Options.GUI,140,0).sel > 0) did -te DLF.Options.GUI 135
  else {
    did -b DLF.Options.GUI 135
    DLF.Options.SetAddChannelButton
  }
}

alias -l DLF.Options.AddChannel {
  var %chan $did(DLF.Options.GUI,120).text
  if ($pos(%chan,$hashtag,0) == 0) %chan = $hashtag $+ %chan
  if (($scon(0) == 1) && ($left(%chan,1) == $hashtag)) %chan = $network $+ %chan
  DLF.Chan.Add %chan
  ; Clear edit field, list selection and disable add button
  DLF.Options.InitChannelList
}

alias -l DLF.Options.RemoveChannel {
  var %i $did(DLF.Options.GUI,140,0).sel
  while (%i) {
    DLF.Chan.Remove $did(DLF.Options.GUI,140,$did(DLF.Options.GUI,140,%i).sel).text
    dec %i
  }
  did -b DLF.Options.GUI 135
  DLF.Options.InitChannelList
}

alias -l DLF.Options.EditChannel {
  if ($did(DLF.Options.GUI,140,0).sel == 1 ) {
    var %chan $did(DLF.Options.GUI,140,$did(DLF.Options.GUI,140,1).sel).text
    DLF.Options.RemoveChannel
    DLF.Options.InitChannelList
    did -o DLF.Options.GUI 120 0 %chan
    DLF.Options.SetAddChannelButton
  }
}

alias -l DLF.Options.InitCustomList {
  did -r DLF.Options.GUI 830
  did -a DLF.Options.GUI 830 $+(Channel,$nbsp,text)
  did -a DLF.Options.GUI 830 $+(Channel,$nbsp,action)
  did -a DLF.Options.GUI 830 $+(Channel,$nbsp,notice)
  did -a DLF.Options.GUI 830 $+(Channel,$nbsp,ctcp)
  did -a DLF.Options.GUI 830 $+(Private,$nbsp,text)
  did -a DLF.Options.GUI 830 $+(Private,$nbsp,action)
  did -a DLF.Options.GUI 830 $+(Private,$nbsp,notice)
  did -a DLF.Options.GUI 830 $+(Private,$nbsp,ctcp)
  did -c DLF.Options.GUI 830 1
  DLF.Options.SetCustomType
}

alias -l DLF.Options.About {
  did -r DLF.Options.GUI 920
  if ($fopen(dlFilter)) .fclose dlFilter
  .fopen dlFilter $script
  var %line $fread(dlFilter)
  while ((!$feof) && (!$ferr) && ($left(%line,2) != $+(/,*))) {
    %line = $fread(dlFilter)
  }
  if (($feof) || ($ferr)) {
    if ($fopen(dlFilter)) .fclose dlFilter
    did -a DLF.Options.GUI 920 Unable to populate About tab.
    return
  }
  var %i 0
  %line = $fread(dlFilter)
  while ((!$feof) && (!$ferr) && ($left(%line,2) != $+(*,/))) {
    did -a DLF.Options.GUI 920 %line $+ $crlf
    inc %i
    %line = $fread(dlFilter)
  }
  .fclose dlFilter
}

alias -l DLF.Options.SetCustomType {
  var %selected $replace($did(DLF.Options.GUI,830).seltext,$nbsp,$space)
  did -r DLF.Options.GUI 870
  if (%selected == Channel text) didtok DLF.Options.GUI 870 44 %DLF.custom.chantext
  elseif (%selected == Channel action) didtok DLF.Options.GUI 870 44 %DLF.custom.chanaction
  elseif (%selected == Channel notice) didtok DLF.Options.GUI 870 44 %DLF.custom.channotice
  elseif (%selected == Channel ctcp) didtok DLF.Options.GUI 870 44 %DLF.custom.chanctcp
  elseif (%selected == Private text) didtok DLF.Options.GUI 870 44 %DLF.custom.privtext
  elseif (%selected == Private action) didtok DLF.Options.GUI 870 44 %DLF.custom.privaction
  elseif (%selected == Private notice) didtok DLF.Options.GUI 870 44 %DLF.custom.privnotice
  elseif (%selected == Private ctcp) didtok DLF.Options.GUI 870 44 %DLF.custom.privctcp
  else DLF.Error DLF.Options.SetCustomType Invalid message type: %selected
}

alias -l DLF.Options.SetAddCustomButton {
  if ($did(DLF.Options.GUI,840)) did -te DLF.Options.GUI 850
  else {
    did -b DLF.Options.GUI 850
    did -t DLF.Options.GUI 50
  }
}

alias -l DLF.Options.SetRemoveCustomButton {
  if ($did(DLF.Options.GUI,870,0).sel > 0) did -te DLF.Options.GUI 860
  else {
    did -b DLF.Options.GUI 860
    DLF.Options.SetAddCustomButton
  }
}

alias -l DLF.Options.AddCustom {
  var %selected $did(DLF.Options.GUI,830).seltext
  var %new $did(DLF.Options.GUI,840).text
  if (* !isin %new) var %new $+(*,%new,*)
  DLF.Custom.Add %selected %new
  ; Clear edit field, list selection and disable add button
  did -r DLF.Options.GUI 840
  DLF.Options.SetAddCustomButton
  DLF.Options.SetCustomType
}

alias -l DLF.Options.RemoveCustom {
  var %selected $did(DLF.Options.GUI,830).seltext
  var %i $did(DLF.Options.GUI,870,0).sel
  while (%i) {
    DLF.Custom.Remove %selected $did(DLF.Options.GUI,870,$did(DLF.Options.GUI,870,%i).sel).text
    dec %i
  }
  did -b DLF.Options.GUI 860
  DLF.Options.SetCustomType
  DLF.Options.SetRemoveCustomButton
}

alias -l DLF.Options.EditCustom {
  if ($did(DLF.Options.GUI,870,0).sel == 1 ) {
    did -o DLF.Options.GUI 840 1 $did(DLF.Options.GUI,870,$did(DLF.Options.GUI,870,1).sel).text
    DLF.Options.RemoveCustom
    DLF.Options.SetAddCustomButton
  }
}

alias -l DLF.Options.DownloadUpdate {
  did -b DLF.Options.GUI 180
  DLF.Download.Run
}

alias -l DLF.Options.Status {
  if ($dialog(DLF.Options.GUI)) did -o DLF.Options.GUI 160 1 $1-
  DLF.StatusAll $1-
}

alias -l DLF.Options.Error {
}

; ========== Check version for updates ==========
; Check once per week for normal releases and once per day if user is wanting betas
alias -l DLF.Update.Check {
  var %days $ctime - %DLF.update.lastcheck
  var %days %days / 86400
  var %days $int(%days)
  if ((%days >= 7) || ((%DLF.update.betas) && (%days >= 1))) DLF.Update.Run
}

alias -l DLF.Update.Run {
  if ($dialog(DLF.Options.GUI)) did -b DLF.Options.GUI 180
  DLF.Options.Status Checking for dlFilter updates…
  DLF.Socket.Get Update https://raw.githubusercontent.com/DukeLupus/dlFilter/master/dlFilter.version
}

on *:sockread:DLF.Socket.Update: {
  DLF.Socket.Headers
  var %line, %mark $sock($sockname).mark
  var %state $gettok(%mark,1,$asc($space))
  if (%state != Body) DLF.Socket.Error Cannot process response: Still processing %state
  unset %DLF.version.web
  unset %DLF.version.web.mirc
  unset %DLF.version.beta
  unset %DLF.version.beta.mirc
  while ($true) {
    sockread %line
    if ($sockerr > 0) DLF.Socket.SockErr sockread:Body
    if ($sockbr == 0) break
    DLF.Update.ProcessLine %line
  }
}

on *:sockclose:DLF.Socket.Update: {
  var %line
  sockread -f %line
  if ($sockerr > 0) DLF.Socket.SockErr sockclose
  if ($sockbr > 0) DLF.Update.ProcessLine %line
  DLF.Update.CheckVersions
}

alias -l DLF.Update.ProcessLine {
  if ($gettok($1-,1,$asc(|)) == dlFilter) {
    %DLF.version.web = $gettok($1-,2,$asc(|))
    %DLF.version.web.mirc = $gettok($1-,3,$asc(|))
    %DLF.version.web.comment = $gettok($1-,4,$asc(|))
    set %DLF.update.lastcheck $ctime
  }
  elseif ($gettok($1-,1,$asc(|)) == dlFilter.beta) {
    %DLF.version.beta = $gettok($1-,2,$asc(|))
    %DLF.version.beta.mirc = $gettok($1-,3,$asc(|))
    %DLF.version.beta.comment = $gettok($1-,4,$asc(|))
  }
}

alias -l DLF.Update.CheckVersions {
  if ($dialog(DLF.Options.GUI)) did -b DLF.Options.GUI 180
  if (%DLF.version.web) {
    if ((%DLF.update.betas) $&
      && (%DLF.version.beta) $&
      && (%DLF.version.beta > %DLF.version.web)) {
      if (%DLF.version.beta > $DLF.SetVersion) DLF.Update.DownloadAvailable beta %DLF.version.beta %DLF.version.beta.mirc %DLF.version.beta.comment
      elseif (%DLF.version.web == $DLF.SetVersion) DLF.Options.Status Running current version of dlFilter beta
      else DLF.Options.Status Running a newer version $br($DLF.SetVersion) than web beta version $br(%DLF.version.beta)
    }
    elseif (%DLF.version.web > $DLF.SetVersion) DLF.Update.DownloadAvailable production %DLF.version.web %DLF.version.web.mirc %DLF.version.web.comment
    elseif (%DLF.version.web == $DLF.SetVersion) DLF.Options.Status Running current version of dlFilter
    else DLF.Options.Status Running a newer version $br($DLF.SetVersion) than website $br(%DLF.version.web)
  }
  else DLF.Socket.Error dlFilter version missing!
}

alias -l DLF.Update.DownloadAvailable {
  var %ver $1 version $2
  if ($4-) %ver = %ver - $4-
  if ($version >= $3) {
    DLF.Options.Status You can update dlFilter to %ver
    did -e DLF.Options.GUI 180
  }
  else DLF.Options.Status Upgrade mIRC before you can update dlFilter to %ver

  var %net $scon(0)
  while (%net) {
    scon %net
    var %i $chan(0)
    while (%i) {
      var %chan = $chan(%i)
      if ($DLF.Chan.IsDlfChan(%cchan)) DLF.Update.ChanAnnounce %chan $1-
      dec %i
    }
    dec %net
  }
  scon -r
}

; Announce new version whenever user joins an enabled channel.
alias -l DLF.Update.Announce {
  DLF.Watch.Called DLF.Update.Announce
  if (%DLF.version.web) {
    if ((%DLF.update.betas) $&
      && (%DLF.version.beta) $&
      && (%DLF.version.beta > %DLF.version.web) $&
      && (%DLF.version.beta > $DLF.SetVersion)) DLF.Update.ChanAnnounce $chan production %DLF.version.beta %DLF.version.beta.mirc %DLF.version.beta.comment
    elseif (%DLF.version.web > $DLF.SetVersion) DLF.Update.ChanAnnounce $chan beta %DLF.version.web %DLF.version.web.mirc %DLF.version.web.comment
  }
}

alias -l DLF.Update.ChanAnnounce {
  var %ver $3
  if ($5-) %ver = %ver $+ : $5-
  else %ver = %ver $+ .
  echo -t $1 $c(1,9,$DLF.logo A new $2 version of dlFilter is available: version %ver)
  if ($4 > $version) echo -t $1 $c(1,9,$DLF.logo However you need to $c(4,upgrade mIRC) to > v $+ $4 before you can download it.)
  else echo -t $1 $c(1,9,$DLF.logo Use the Update button in dlFilter Options to download and install.)
}

; ========== Download new version ==========
alias -l DLF.Download.Run {
  DLF.Options.Status Downloading new version of dlFilter…
  var %newscript $qt($script $+ .new)
  if ($isfile(%newscript)) .remove %newscript
  if ($exists(%newscript)) DLF.Socket.Error Unable to delete old temporary download file.
  var %branch master
  if ((%DLF.update.betas == 1) && (%DLF.version.beta > %DLF.version.web)) %branch = beta
  DLF.Socket.Get Download $+(https:,//raw.githubusercontent.com/DukeLupus/dlFilter/,%branch,/dlFilter.mrc)
}

on *:sockread:DLF.Socket.Download: {
  DLF.Socket.Headers
  var %mark $sock($sockname).mark
  var %state $gettok(%mark,1,$asc($space))
  if (%state != Body) DLF.Socket.Error Cannot process response: Still processing %state
  var %newscript $qt($script $+ .new)
  while ($true) {
    sockread &block
    if ($sockerr > 0) DLF.Socket.SockErr sockread:Body
    if ($sockbr == 0) break
    bwrite %newscript -1 -1 &block
  }
}

on *:sockclose:DLF.Socket.Download: {
  var %newscript $qt($script $+ .new)
  var %oldscript $qt($script $+ .v $+ $DLF.SetVersion)
  var %oldsaved $false
  sockread -f &block
  if ($sockerr > 0) DLF.Socket.SockErr sockclose
  if ($sockbr > 0) bwrite %newscript -1 -1 &block
  if ($isfile(%oldscript)) .remove %oldscript
  if ($exists(%oldscript)) .remove $script
  else {
    .rename $script %oldscript
    %oldsaved = $true
  }
  .rename %newscript $script
  %DLF.version = %DLF.version.web
  DLF.Options.Status New version of dlFilter downloaded and installed
  if (%oldsaved) DLF.StatusAll Old version of dlFilter.mrc saved as %oldscript in case you need to revert
  signal DLF.Initialise
  .reload -rs1 $script
}

alias -l DLF.Download.Error {
  DLF.Update.ErrorMsg Unable to download new version of dlFilter!
}

; ========== Socket utilities ==========
; Modified version of https://www.rosettacode.org/wiki/HTTP/MIRC_Scripting_Language
; Example:
;     DLF.Socket.Get sockname http://www.example.com/somefile.txt [dialog id]
;     on *:SOCKREAD:DLF.Socket.sockname: {
;        DLF.Socket.Headers
;        while ($true) {
;          sockread %line
;          sockread %line
;          if ($sockerr > 0) DLF.Socket.SockErr sockread:Body
;          if ($sockbr == 0) break
;          your code to process body
;        }
;     }
; "on SOCKOPEN" is not needed

alias -l DLF.Socket.Get DLF.Socket.Open $+(DLF.Socket.,$1) $2-

alias -l DLF.Socket.Open {
  var %socket $1
  var %url $2
  var %dialog $3
  var %dialogid $4

  ; Regular expression to parse the url:
  var %re /^(?:(https?)(?::\/\/))?([^\s\/]+)(.*)$/F
  if ($regex(DLF.Socket.Get,$2,%re) !isnum 1-) DLF.Socket.Error Invalid url: %2

  var %protocol $regml(DLF.Socket.Get,1)
  var %hostport $regml(DLF.Socket.Get,2)
  var %path $regml(DLF.Socket.Get,3)
  var %host $gettok(%hostport,1,$asc(:))
  var %port $gettok(%hostport,2,$asc(:))

  if (%protocol == $null) %protocol = http
  if (%path == $null) %path = /
  if (%port == $null) {
    if (%protocol == https) %port = 443
    else %port = 80
  }
  if (%port == 443) %protocol = https
  %hostport = $+(%host,:,$port)

  if ($sock(%socket)) sockclose %socket
  var %flag
  if (%protocol == https) %flag = -e
  sockopen %flag %socket %host %port
  sockmark %socket Opening %host %path %dialog %dialogid
}

on *:sockopen:DLF.Socket.*:{
  if ($sockerr) DLF.Socket.SockErr connecting

  ; Mark: Opening %host %path %dialog %dialogid
  var %line, %mark $sock($sockname).mark
  var %state $gettok(%mark,1,$asc($space))
  var %host $gettok(%mark,2,$asc($space))
  var %path $gettok(%mark,3,$asc($space))
  if (%state != Opening) DLF.Socket.Error Socket Open status invalid: %state
  sockmark $sockname $puttok(%mark,Requested,1,$asc($space))

  var %sw sockwrite -tn $sockname
  %sw GET %path HTTP/1.1
  %sw Host: %host
  %sw Connection: Close
  %sw $crlf
}

alias -l DLF.Socket.Headers {
  if ($sockerr) DLF.Socket.SockErr sockread

  var %line, %mark $sock($sockname).mark
  var %state $gettok(%mark,1,$asc($space))
  ; if on SOCKREAD called for second time, then return immediately
  if (%state == Body) return

  while ($true) {
    sockread %line
    if ($sockerr) DLF.Socket.SockErr sockread
    if ($sockbr == 0) DLF.Socket.Error Server response empty or truncated

    if (%state == Requested) {
      ; Requested: Process first header line which is Status code
      ; HTTP/1.x status-code status-reason
      var %version $gettok(%line,1,$asc($space))
      var %code $gettok(%line,2,$asc($space))
      var %reason $gettok(%line,3-,$asc($space))
      if (2?? iswm %code) {
        ; 2xx codes indicate it went ok
        %state = Headers
        sockmark $sockname $puttok(%mark,%state,1,$asc($space))
      }
      elseif (3?? iswm %code) {
        ; 3xx codes indicate redirection
        %state = Redirect
        sockmark $sockname $puttok(%mark,%state,1,$asc($space))
      }
      else DLF.Socket.Error $sockname get failed with status code %code $+ : %reason
    }
    elseif (%state == Redirect) {
      ; No Location header ?
      if ($len(%line) == 0) DLF.Socket.Error $sockname redirect failed: no redirect URL in headers
      var %header $gettok(%line,1,$asc(:))
      if (%header == Location) {
        var %sockname $sockname
        sockclose $sockname
        DLF.Socket.Open %sockname $gettok(%line,2-,$asc(:)) $gettok(%mark,4-,$asc($space))
        halt
      }
    }
    elseif (%state == Headers) {
      if ($len(%line) == 0) {
        sockmark $sockname $puttok(%mark,Body,1,$asc($space))
        return
      }
    }
  }
}

alias -l DLF.Socket.SockErr DLF.Socket.Error $1: $sock($sockname).wsmsg

alias -l DLF.Socket.Error {
  if ($sockname) {
    var %mark $sock($sockname).mark
    var %msg $+($sockname,: http,$iif($sock($sockname).ssl,s),://,$gettok(%mark,2,$asc($space)),$gettok(%mark,3,$asc($space)),:) $1-
    sockclose $sockname
    if ($dialog(DLF.Options.GUI)) did -o DLF.Options.GUI 160 1 Communications error whilst $1-
    DLF.Error %msg
  }
  else DLF.Error $1-
}

; ========== Create dlFilter.gif if needed ==========
alias -l DLF.CreateGif {
  bset -ta &gif 1 eJxz93SzsEwUYBBg+M4AArpO837sZhgFo2AEAsWfLIwMDP8ZdEAcUJ5g4PBn
  bset -ta &gif 61 +M8p47Eh4SAD4z9FkwqDh05tzOJ2LSsCGo52S7ByuHQYJLu1yghX7fkR8MiD
  bset -ta &gif 121 UVWWTWKm0JP9/brycT0SQinu3Syqt2I6Jz86MNOOlYmXy0SBwRoAZQAkYg==
  DLF.CreateBinaryFile &gif $+($nofile($script),dlFilter.gif)
}

; ========== Define message matching hash tables ==========
alias -l hiswm {
  var %h DLF. $+ $1
  if (!$hget(%h)) {
    DLF.Warning Hash table %h does not exist - attempting to recreate it…
    DLF.CreateHashTables
  }
  var %result $hfind(%h,$2,1,W).data
  if (%result) %result = $hget(%h,%result)
  ; There is no case sensitive hfind wildcard search, so we need to check that it matches case sensitively.
  ; if ((%result) && (%result !iswmcs $2)) %result = $null
  if (%result) DLF.Watch.Log Matched in $1 by $qt(%result)
  return %result
}

alias -l DLF.hadd {
  var %h DLF. $+ $1
  if (!$hget(%h)) hmake %h 10
  var %n $hget(%h, 0).item
  inc %n
  hadd %h i $+ %n $2-
}

alias -l DLF.CreateHashTables {
  var %matches 0

  if ($hget(DLF.chantext.mistakes)) hfree DLF.chantext.mistakes
  DLF.hadd chantext.mistakes quit
  DLF.hadd chantext.mistakes exit
  DLF.hadd chantext.mistakes :quit
  DLF.hadd chantext.mistakes :exit
  inc %matches $hget(DLF.chantext.mistakes,0).item

  if ($hget(DLF.chantext.ads)) hfree DLF.chantext.ads
  DLF.hadd chantext.ads * CSE Fact *
  DLF.hadd chantext.ads *@*DragonServe*
  DLF.hadd chantext.ads *@*Finålity*
  DLF.hadd chantext.ads *@*SDFind*
  DLF.hadd chantext.ads *Enter @*to see the menu*
  DLF.hadd chantext.ads *Escribe*!*
  DLF.hadd chantext.ads *Escribe*@*
  DLF.hadd chantext.ads *File Server Online*Triggers*Sends*Queues*
  DLF.hadd chantext.ads *File Servers Online*Polaris*
  DLF.hadd chantext.ads *File Servers Online*Trigger*Accessed*Served*
  DLF.hadd chantext.ads *Files In List*slots open*Queued*Next Send*
  DLF.hadd chantext.ads *Files*free Slots*Queued*Speed*Served*
  DLF.hadd chantext.ads *For my list of * files type*@*
  DLF.hadd chantext.ads *For my list*files*type @*
  DLF.hadd chantext.ads *For My Top Download Hit-chart, type @*
  DLF.hadd chantext.ads *Type*@* for my list*
  DLF.hadd chantext.ads *Type*@* to get my list*
  DLF.hadd chantext.ads *FTP service*FTP*port*bookz*
  DLF.hadd chantext.ads *FTP*address*port*login*password*
  DLF.hadd chantext.ads *I have sent a total of*files and leeched a total of*since*
  DLF.hadd chantext.ads *I have spent a total time of*sending files and a total time of*recieving files*
  DLF.hadd chantext.ads List*@*
  DLF.hadd chantext.ads Search: * Mode:*
  DLF.hadd chantext.ads *Pour ma liste écrire*@* fichiers * Slots* utilisé*
  DLF.hadd chantext.ads *Statistici 1*by Un_DuLciC*
  DLF.hadd chantext.ads *Tape*@*
  DLF.hadd chantext.ads *Tapez*Pour avoir ce Fichier*
  DLF.hadd chantext.ads *Tapez*Pour*Ma Liste De*Fichier En Attente*
  DLF.hadd chantext.ads *Tasteazã*@*
  DLF.hadd chantext.ads *Teclea: @*
  DLF.hadd chantext.ads *Total Offered*Files*Total Sent*Files*Total Sent Today*Files*
  DLF.hadd chantext.ads *Trigger*@*
  DLF.hadd chantext.ads *Trigger*ctcp*
  DLF.hadd chantext.ads *Total*File Transfer in Progress*slot*empty*
  DLF.hadd chantext.ads *Type @* list of *
  DLF.hadd chantext.ads *[BWI]*@*
  DLF.hadd chantext.ads @ * is now open via ftp @*
  DLF.hadd chantext.ads @ --*
  DLF.hadd chantext.ads @ Use @*
  DLF.hadd chantext.ads *QNet Advanced DCC File Server*Sharing *B of stuff!*
  inc %matches $hget(DLF.chantext.ads,0).item

  if ($hget(DLF.chantext.spam)) hfree DLF.chantext.spam
  DLF.hadd chantext.spam *Has The Best Servers*We have * Servers Sharing * Files*
  DLF.hadd chantext.spam *§ÐfíñÐ âÐÐ-øñ§*
  DLF.hadd chantext.spam *« Ë×Çü®§îöñ »*
  DLF.hadd chantext.spam *away*since*pager*
  DLF.hadd chantext.spam *Back*Duration*
  DLF.hadd chantext.spam *BJFileTracker V06 by BossJoe*
  DLF.hadd chantext.spam *Combined channel status:*
  DLF.hadd chantext.spam *DCC Send Failed of*to*Starting next in Que*
  DLF.hadd chantext.spam *get - from*at*cps*complete*
  DLF.hadd chantext.spam *HêåvêñlyAway*
  DLF.hadd chantext.spam *has just received*for a total of*
  DLF.hadd chantext.spam *have just finished recieving*from*I have leeched a total*
  DLF.hadd chantext.spam *I am AWAY*Reason*I have been Away for*
  DLF.hadd chantext.spam *I am AWAY*Reason*To page me*
  DLF.hadd chantext.spam *I have just finished receiving*from*
  DLF.hadd chantext.spam *I have just finished sending * to *
  DLF.hadd chantext.spam *I have just finished receiving*from*have now received a total*
  DLF.hadd chantext.spam *I have just received*from*for a total of*KeepTrack*
  DLF.hadd chantext.spam *I have just received*from*leeched since*
  DLF.hadd chantext.spam *Je viens juste de terminer de recevoir*de*Prenez-en un vite*
  DLF.hadd chantext.spam *Just Sent To*Filename*Slots Free*Queued*
  DLF.hadd chantext.spam *KeepTrack*by*^OmeN*
  DLF.hadd chantext.spam *KeepTrack*de adisoru*
  DLF.hadd chantext.spam *KiLLJarX*channel policy is that we are a*
  DLF.hadd chantext.spam *Leaving*reason*auto away after*
  DLF.hadd chantext.spam *Message*SysReset*
  DLF.hadd chantext.spam *MisheBORG*SendStat*v.*
  DLF.hadd chantext.spam *mp3 server detected*
  DLF.hadd chantext.spam *rßPLåY2.0*
  DLF.hadd chantext.spam *rbPlay20.mrc*
  DLF.hadd chantext.spam *Receive Successful*Thanks for*
  DLF.hadd chantext.spam *Received*From*Size*Speed*Time*since*
  DLF.hadd chantext.spam *ROLL TIDE*Now Playing*mp3*
  DLF.hadd chantext.spam *sent*to*at*total sent*files*yesterday*files*today*files*
  DLF.hadd chantext.spam *sets away*auto idle away*since*
  DLF.hadd chantext.spam *Thank You*for serving in*
  DLF.hadd chantext.spam *Thanks for the +v*
  DLF.hadd chantext.spam *Thanks for the @*
  DLF.hadd chantext.spam *Thanks*for Supplying an server in*
  DLF.hadd chantext.spam *Thanks*For The*@*
  DLF.hadd chantext.spam *Thanks*For*The*Voice*
  DLF.hadd chantext.spam * to * just got timed out*slot*Empty*
  DLF.hadd chantext.spam *Tocmai am primit*KeepTrack*
  DLF.hadd chantext.spam *Total Received*Files*Total Received Today*Files*
  DLF.hadd chantext.spam *Tx TIMEOUT*
  DLF.hadd chantext.spam Type*!*.* To Get This *
  DLF.hadd chantext.spam *WaS auTo-VoiCeD THaNX FoR SHaRiNG HeRe iN*
  DLF.hadd chantext.spam *We have just finished receiving*From The One And Only*
  DLF.hadd chantext.spam *Welcome back to #* operator*.*
  DLF.hadd chantext.spam *YAY* Another brave soldier in the war to educate the masses*Onward Comrades*
  DLF.hadd chantext.spam *[Away]*SysReset*
  DLF.hadd chantext.spam *[F][U][N]*
  DLF.hadd chantext.spam Request * —I-n-v-i-s-i-o-n—
  DLF.hadd chantext.spam *Tape*!*.mp3*
  DLF.hadd chantext.spam *Tape*!*MB*
  DLF.hadd chantext.spam *!*.mp3*SpR*
  DLF.hadd chantext.spam *!*MB*Kbps*Khz*
  DLF.hadd chantext.spam *Sent*to*OS-Limits v*
  DLF.hadd chantext.spam *<><><*><><>*
  DLF.hadd chantext.spam *~*~SpR~*~*
  DLF.hadd chantext.spam *I have just finished recieving*from*I have now recieved a total of*
  DLF.hadd chantext.spam *I have just finished sending*.mp3 to*
  DLF.hadd chantext.spam *I have just finished sending*I have now sent a total of*files since*
  DLF.hadd chantext.spam *I have just finished sending*to*Empty*
  DLF.hadd chantext.spam *Random Play * Now Activated*
  DLF.hadd chantext.spam *-SpR-*
  DLF.hadd chantext.spam *SPr*!*.mp3*
  DLF.hadd chantext.spam *SpR*[*mp3*]*
  DLF.hadd chantext.spam *Tape*!* Pour Voir Vos Statistiques*
  DLF.hadd chantext.spam *Type*!* To Get This*
  DLF.hadd chantext.spam *Welcome * person No* to join*
  DLF.hadd chantext.spam *'s current status * Points this WEEK * Points this MONTH*
  DLF.hadd chantext.spam *- ??/??/????  *  Ajouté par *
  DLF.hadd chantext.spam Mode: Normal
  DLF.hadd chantext.spam Normal
  DLF.hadd chantext.spam ø
  DLF.hadd chantext.spam *Je Vient Juste De Reçevoir * De La Pars De * Pour Un Total De * Fichier(s)*
  DLF.hadd chantext.spam *The fastest Average Send Speeds captured last hour are*
  DLF.hadd chantext.spam *Todays Most Popular Servers - as of *
  DLF.hadd chantext.spam *Todays Top Leechers - as of *
  DLF.hadd chantext.spam *I have just voiced * for being kewl And sharing*
  DLF.hadd chantext.spam *I-n-v-i-s-i-o-n*
  DLF.hadd chantext.spam *¥*Mp3s*¥*
  DLF.hadd chantext.spam *§*DCC Send Failed*to*§*
  DLF.hadd chantext.spam *§kÎn§*ßy*§hådõ*
  DLF.hadd chantext.spam *©§©*
  DLF.hadd chantext.spam *« * » -*
  DLF.hadd chantext.spam *«Scøøp MP3»*
  DLF.hadd chantext.spam *±*
  DLF.hadd chantext.spam *» Port «*»*
  DLF.hadd chantext.spam *- DCC Transfer Status -*
  DLF.hadd chantext.spam *--PepsiScript--*
  DLF.hadd chantext.spam *-SpR skin used by PepsiScript*
  DLF.hadd chantext.spam *.mp3*t×PLåY6*
  DLF.hadd chantext.spam *a recu*pour un total de*fichiers*
  DLF.hadd chantext.spam *Bandwith*Usage*Current*Record*
  DLF.hadd chantext.spam *Control*IRC Client*CTCPSERV*
  DLF.hadd chantext.spam *DCC GET COMPLETE*from*slot*open*
  DLF.hadd chantext.spam *DCC SEND COMPLETE*to*slot*
  DLF.hadd chantext.spam *DCC Send Failed of*to*
  DLF.hadd chantext.spam *Download this exciting book*
  DLF.hadd chantext.spam *failed*DCC Send Failed of*to*failed*
  DLF.hadd chantext.spam *I am opening up*more slot*Taken*
  DLF.hadd chantext.spam *I am using*SpR JUKEBOX*http://spr.darkrealms.org*
  DLF.hadd chantext.spam *is playing*info*secs*
  DLF.hadd chantext.spam *Je viens juste de terminer l'envoi de*Prenez-en un vite*
  DLF.hadd chantext.spam *just left*Sending file Aborted*
  DLF.hadd chantext.spam *left irc and didn't return in*min. Sending file Aborted*
  DLF.hadd chantext.spam *left*and didn't return in*mins. Sending file Aborted*
  DLF.hadd chantext.spam *Now Sending*QwIRC*
  DLF.hadd chantext.spam *OmeNServE*©^OmeN^*
  DLF.hadd chantext.spam *Proofpack Server*Looking for new scans to proof*@proofpack for available proofing packs*
  DLF.hadd chantext.spam *rßP£a*sk*n*
  DLF.hadd chantext.spam *rßPLåY*
  DLF.hadd chantext.spam *Random Play MP3 filez Now Plugged In*
  DLF.hadd chantext.spam *Random Play MP3*Now Activated*
  DLF.hadd chantext.spam *Rank*~*x*~*
  DLF.hadd chantext.spam *send - to*at*cps*complete*left*
  DLF.hadd chantext.spam *sent*to*size*speed*time*sent*
  DLF.hadd chantext.spam *Softwind*Softwind*
  DLF.hadd chantext.spam *SpR JUKEBOX*filesize*
  DLF.hadd chantext.spam *Successfully*Tx.Track*
  DLF.hadd chantext.spam *tìnkërßëll`s collection*Love Quotes*
  DLF.hadd chantext.spam *The Dcc Transfer to*has gone under*Transfer*
  DLF.hadd chantext.spam *There is a Slot Opening*Grab it Fast*
  DLF.hadd chantext.spam *There is a*Open*Say's Grab*
  DLF.hadd chantext.spam *To serve and to be served*@*
  DLF.hadd chantext.spam *User Slots*Sends*Queues*Next Send Available*¤UControl¤*
  DLF.hadd chantext.spam *vient d'etre interrompu*Dcc Libre*
  DLF.hadd chantext.spam *Welcome to #*, we have * detected servers online to serve you*
  DLF.hadd chantext.spam *Wireless*mb*br*
  DLF.hadd chantext.spam *[Fserve Active]*
  DLF.hadd chantext.spam *[Mp3xBR]*
  DLF.hadd chantext.spam Thanks for serving *
  DLF.hadd chantext.spam Escribe: * !*.mp3*
  inc %matches $hget(DLF.chantext.spam,0).item

  if ($hget(DLF.chantext.always)) hfree DLF.chantext.always
  DLF.hadd chantext.always "find *
  DLF.hadd chantext.always #find *
  DLF.hadd chantext.always quit
  DLF.hadd chantext.always exit
  DLF.hadd chantext.always *- * bytes
  DLF.hadd chantext.always *- *.?? K
  DLF.hadd chantext.always *- *.?? M
  DLF.hadd chantext.always *- *.?? KB
  DLF.hadd chantext.always *- *.?? MB
  DLF.hadd chantext.always *- *.? KB
  DLF.hadd chantext.always *- *.? MB
  DLF.hadd chantext.always ---*KB*s*
  DLF.hadd chantext.always ---*MB*s*
  DLF.hadd chantext.always 2find *
  DLF.hadd chantext.always Sign in to turn on 1-Click ordering.
  DLF.hadd chantext.always *::INFO:: *.*KB
  DLF.hadd chantext.always *::INFO:: *.*MB
  DLF.hadd chantext.always <*> *
  inc %matches $hget(DLF.chantext.always,0).item

  if ($hget(DLF.chantext.dlf)) hfree DLF.chantext.dlf
  DLF.hadd chantext.dlf $strip($DLF.logo) *
  inc %matches $hget(DLF.chantext.dlf,0).item

  if ($hget(DLF.chanaction.away)) hfree DLF.chanaction.away
  DLF.hadd chanaction.away *asculta*
  DLF.hadd chanaction.away *Avertisseur*Journal*
  DLF.hadd chanaction.away *está away*pager*
  DLF.hadd chanaction.away *has returned from*I was gone for*
  DLF.hadd chanaction.away *has stumbled to the channel couch*Couch v*by Kavey*
  DLF.hadd chanaction.away *has taken a seat on the channel couch*Couch v*by Kavey*
  DLF.hadd chanaction.away *I Have Send My List*Times*Files*Times*
  DLF.hadd chanaction.away *I-n-v-i-s-i-o-n*
  DLF.hadd chanaction.away *is AWAY*auto-away*
  DLF.hadd chanaction.away *is away*Reason*since*
  DLF.hadd chanaction.away *is BACK from*away*
  DLF.hadd chanaction.away *is back from*Gone*
  DLF.hadd chanaction.away *is currently boogying away to*
  DLF.hadd chanaction.away *is gone. Away after*minutes of inactivity*
  DLF.hadd chanaction.away *is listening to*Kbps*KHz*
  DLF.hadd chanaction.away *Now*Playing*Kbps*KHz*
  DLF.hadd chanaction.away *sets away*Auto Idle Away after*
  DLF.hadd chanaction.away *Type Or Copy*Paste*To Get This Song*
  DLF.hadd chanaction.away *uses cracked software*I will respond to the following commands*
  DLF.hadd chanaction.away *way*since*pager*
  DLF.hadd chanaction.away *[Backing Up]*
  inc %matches $hget(DLF.chanaction.away,0).item

  if ($hget(DLF.chanaction.spam)) hfree DLF.chanaction.spam
  DLF.hadd chanaction.spam *FTP*port*user*pass*
  DLF.hadd chanaction.spam *get AMIP*plug-in at http*amip.tools-for.net*
  inc %matches $hget(DLF.chanaction.spam,0).item

  if ($hget(DLF.channotice.spam)) hfree DLF.channotice.spam
  DLF.hadd channotice.spam *free-download*
  DLF.hadd channotice.spam *WWW.TURKSMSBOT.CJB.NET*
  inc %matches $hget(DLF.channotice.spam,0).item

  if ($hget(DLF.chanctcp.spam)) hfree DLF.chanctcp.spam
  DLF.hadd chanctcp.spam ASF*
  DLF.hadd chanctcp.spam MP*
  DLF.hadd chanctcp.spam RAR*
  DLF.hadd chanctcp.spam SOUND*
  DLF.hadd chanctcp.spam WMA*
  DLF.hadd chanctcp.spam SLOTS*
  inc %matches $hget(DLF.chanctcp.spam,0).item

  if ($hget(DLF.chanctcp.server)) hfree DLF.chanctcp.server
  DLF.hadd chanctcp.server *OmeNServE*
  inc %matches $hget(DLF.chanctcp.server,0).item

  if ($hget(DLF.privtext.spam)) hfree DLF.privtext.spam
  DLF.hadd privtext.spam *http*sex*
  DLF.hadd privtext.spam *http*xxx*
  DLF.hadd privtext.spam *porn*http*
  DLF.hadd privtext.spam *sex*http*
  DLF.hadd privtext.spam *sex*www*
  DLF.hadd privtext.spam *www*sex*
  DLF.hadd privtext.spam *www*xxx*
  DLF.hadd privtext.spam *xxx*http*
  DLF.hadd privtext.spam *xxx*www*
  inc %matches $hget(DLF.privtext.spam,0).item

  if ($hget(DLF.privtext.server)) hfree DLF.privtext.server
  DLF.hadd privtext.server *Empieza transferencia*IMPORTANTE*dccallow*
  DLF.hadd privtext.server *I don't have*Please check your spelling or get my newest list by typing @* in the channel*
  DLF.hadd privtext.server *Petición rechazada*DragonServe*
  DLF.hadd privtext.server *Please standby for acknowledgement. I am using a secure query event*
  DLF.hadd privtext.server *Queue Status*File*Position*Waiting Time*OmeNServE*
  DLF.hadd privtext.server *Request Denied*OmeNServE*
  DLF.hadd privtext.server *Request Denied*Reason: *DragonServe*
  DLF.hadd privtext.server *Sorry for cancelling this send*OmeNServE*
  DLF.hadd privtext.server *Sorry, I'm too busy to send my list right now, please try later*
  DLF.hadd privtext.server After * min(s) in my * queue, * is *
  DLF.hadd privtext.server You already have * in my queue*
  DLF.hadd privtext.server You have * files in my * queue*
  DLF.hadd privtext.server I have successfully sent you*OS*
  DLF.hadd privtext.server Lo Siento, no te puedo enviar mi lista ahora, intenta despues*
  DLF.hadd privtext.server Lo siento, pero estoy creando una nueva lista ahora*
  DLF.hadd privtext.server Sorry, I'm making a new list right now, please try later*
  inc %matches $hget(DLF.privtext.server,0).item

  if ($hget(DLF.privtext.away)) hfree DLF.privtext.away
  DLF.hadd privtext.away *AFK, auto away after*minutes. Gone*
  DLF.hadd privtext.away *automated msg*
  DLF.hadd privtext.away *Away*Reason*Auto Away*
  DLF.hadd privtext.away *Away*Reason*Duration*
  DLF.hadd privtext.away *Away*Reason*Gone for*Pager*
  DLF.hadd privtext.away *Away*SysReset*
  DLF.hadd privtext.away *Dacia Script v1.2*
  DLF.hadd privtext.away *If i didn't know any better*I would have thought you were flooding me*
  DLF.hadd privtext.away *Message's from strangers are Auto-Rejected*
  DLF.hadd privtext.away *^Auto-Thanker^*
  inc %matches $hget(DLF.privtext.away,0).item

  if ($hget(DLF.privnotice.server)) hfree DLF.privnotice.server
  DLF.hadd privnotice.server *«OmeN»*
  DLF.hadd privnotice.server *«SoftServe»*
  DLF.hadd privnotice.server *«[RDC]»*
  DLF.hadd privnotice.server *±*
  DLF.hadd privnotice.server *AFK, auto away after*minutes*
  DLF.hadd privnotice.server After * min(s) in my * queue, *
  DLF.hadd privnotice.server After waiting*min*
  DLF.hadd privnotice.server *Ahora has recibido*DragonServe*
  DLF.hadd privnotice.server *archivos, Disfrutalo*
  DLF.hadd privnotice.server *DCC Get of*FAILED Please Re-Send file*
  DLF.hadd privnotice.server *de mi lista de espera*
  DLF.hadd privnotice.server *Después de esperar*min*
  DLF.hadd privnotice.server *Empieza transferencia*DragonServe*
  DLF.hadd privnotice.server *Envío completo*DragonServe*
  DLF.hadd privnotice.server *Enviando*(*)*
  DLF.hadd privnotice.server *Envio cancelado*
  DLF.hadd privnotice.server *esta en camino!*
  DLF.hadd privnotice.server *file not located*
  DLF.hadd privnotice.server *File Transfer of*
  DLF.hadd privnotice.server *Gracias*Ahora he recibido*DragonServe*
  DLF.hadd privnotice.server *Has Been Placed In The Priority Queue At Position*Omenserve*
  DLF.hadd privnotice.server *has been sent successfully*
  DLF.hadd privnotice.server *has been sent sucessfully*
  DLF.hadd privnotice.server *I don't have the file*
  DLF.hadd privnotice.server *I have added*
  DLF.hadd privnotice.server *I'm currently away*your message has been logged*
  DLF.hadd privnotice.server *If your message is urgent, you may page me by typing*PAGE*
  DLF.hadd privnotice.server *is not found*
  DLF.hadd privnotice.server *is on it's way!*
  DLF.hadd privnotice.server *is on its way*
  DLF.hadd privnotice.server *is on the way!*
  DLF.hadd privnotice.server *Keeptrack*omen*
  DLF.hadd privnotice.server *Le Transfert de*Est Completé*
  DLF.hadd privnotice.server *Now I have received*DragonServe*
  DLF.hadd privnotice.server *OmeNServE v*
  DLF.hadd privnotice.server *on its way*
  DLF.hadd privnotice.server *OS-Limites V*t×PLåY*
  DLF.hadd privnotice.server *OS-Limits*
  DLF.hadd privnotice.server *Please make a resume request!*
  DLF.hadd privnotice.server *Please reinitiate File-transfer!*
  DLF.hadd privnotice.server *Query refused*in*seconds*
  DLF.hadd privnotice.server *rßPLåY2*
  DLF.hadd privnotice.server *Request Accepted*File*Queue position*
  DLF.hadd privnotice.server *Request Accepted*List Has Been Placed In The Priority Queue At Position*
  DLF.hadd privnotice.server Request Accepted*Has Been Placed In The Priority Queue At Position*
  DLF.hadd privnotice.server *Request Denied*
  DLF.hadd privnotice.server *request for*acknowledged*send will be initiated as soon as possible*
  DLF.hadd privnotice.server *Requested File's*
  DLF.hadd privnotice.server *Send Complete*File*Sent*times*
  DLF.hadd privnotice.server *Send Failed*at*Please make a resume request*
  DLF.hadd privnotice.server *send will be initiated as soon as possible*
  DLF.hadd privnotice.server *Sent*Files Allowed per day*User Class*BWI-Limits*
  DLF.hadd privnotice.server *Starting Transfer*DragonServe*
  DLF.hadd privnotice.server *t×PLÅY*
  DLF.hadd privnotice.server *t×PLåY*
  DLF.hadd privnotice.server *Thank You*I have now received*file*from you*for a total of*
  DLF.hadd privnotice.server *Thanks For File*It is File*That I have recieved*
  DLF.hadd privnotice.server *Thanks*for sharing*with me*
  DLF.hadd privnotice.server *This makes*times*
  DLF.hadd privnotice.server *Transfer Complete*I have successfully sent*QwIRC
  DLF.hadd privnotice.server *Transfer Complete*sent*
  DLF.hadd privnotice.server *Transfer Started*File*
  DLF.hadd privnotice.server *Transmision de*finalizada*
  DLF.hadd privnotice.server *U Got A File From Me*files since*
  DLF.hadd privnotice.server *Unable to locate any files with*associated within them*
  DLF.hadd privnotice.server *veces que env*
  DLF.hadd privnotice.server *veces que he enviado*
  DLF.hadd privnotice.server *You Are Downloader Number*Overall Downloader Number*
  DLF.hadd privnotice.server *You are in*
  DLF.hadd privnotice.server *You are the successful downloader number*
  DLF.hadd privnotice.server You have * files in my * queue
  DLF.hadd privnotice.server *You have now received*from me*for a total of*sent since*
  DLF.hadd privnotice.server *Your send of*was successfully completed*
  DLF.hadd privnotice.server *zip va en camino*
  DLF.hadd privnotice.server Thank you for*.*!
  inc %matches $hget(DLF.privnotice.server,0).item

  if ($hget(DLF.privnotice.dnd)) hfree DLF.privnotice.dnd
  DLF.hadd privnotice.dnd *CTCP flood detected, protection enabled*
  DLF.hadd privnotice.dnd *SLOTS My mom always told me not to talk to strangers*
  inc %matches $hget(DLF.privnotice.dnd,0).item

  if ($hget(DLF.Priv.ctcpReply)) hfree DLF.Priv.ctcpReply
  DLF.hadd ctcp.reply ERRMSG*
  DLF.hadd ctcp.reply MP3*
  DLF.hadd ctcp.reply SLOTS*
  inc %matches $hget(DLF.Priv.ctcpReply,0).item

  if ($hget(DLF.find.header)) hfree DLF.find.header
  DLF.hadd find.header *«SoftServe»*
  DLF.hadd find.header *@Find Results*SysReset*
  DLF.hadd find.header *End of @Find*
  DLF.hadd find.header *Fichier* Correspondant pour*Copie*
  DLF.hadd find.header *From list*found*displaying*
  DLF.hadd find.header *I have found*file*for your query*Displaying*
  DLF.hadd find.header *I have*match* for*in listfile*
  DLF.hadd find.header *I have*match*for*Copy and Paste*
  DLF.hadd find.header *I have*match*for*in listfile*
  DLF.hadd find.header *I have*matches for*You might want to get my list by typing*
  DLF.hadd find.header *J'ai Trop de Résultats Correspondants*@*
  DLF.hadd find.header *List trigger:*Slots*Next Send*CPS in use*CPS Record*
  DLF.hadd find.header *Matches for*Copy and paste in channel*
  DLF.hadd find.header *Note*Hey look at what i found!*
  DLF.hadd find.header *Note*MP3-MP3*
  DLF.hadd find.header *OmeN*Search Result*ServE*
  DLF.hadd find.header *Résultat De Recherche*OmeNServE*
  DLF.hadd find.header *Resultado Da Busca*Arquivos*Pegue A Minha Lista De*@*
  DLF.hadd find.header *Resultados De Busqueda*OmenServe*
  DLF.hadd find.header *Resultados de la búsqueda*DragonServe*
  DLF.hadd find.header *Results for your search*DragonServe*
  DLF.hadd find.header *search for*returned*results on list*
  DLF.hadd find.header *Search Result*Matches For*Copy And Paste*
  DLF.hadd find.header *Search Result*Matches For*Get My List Of*Files By Typing @*
  DLF.hadd find.header *Search Result*OmeNServE*
  DLF.hadd find.header *Search Result*Too many files*Type*
  DLF.hadd find.header *Search Results*Found*matches for*Type @*to download my list*
  DLF.hadd find.header *Search Results*QwIRC*
  DLF.hadd find.header *Searched*files and found*matching*To get a file, copy !*
  DLF.hadd find.header *SoftServe*Search result*
  DLF.hadd find.header *Tengo*coincidencia* para*
  DLF.hadd find.header *Tengo*resultado*slots*
  DLF.hadd find.header *Too many results*@*
  DLF.hadd find.header *Total de*fichier*Trouvé*
  DLF.hadd find.header *Total*files found*
  DLF.hadd find.header Found * matching files. Using: Findbot *
  DLF.hadd find.header No match found for*
  inc %matches $hget(DLF.find.header,0).item

  ; ps fileserv special responses
  if ($hget(DLF.find.fileserv)) hfree DLF.find.fileserv
  DLF.hadd find.fileserv *@find·* Searching For..::*::..
  DLF.hadd find.fileserv *found * matches* on my fserve*
  DLF.hadd find.fileserv [*] Matches found in [*] Trigger..::/ctcp *
  DLF.hadd find.fileserv *: (* *.*B)
  DLF.hadd find.fileserv ================================================================================
  DLF.hadd find.fileserv --------------------------------------------------------------------------------
  DLF.hadd find.fileserv QNet File Server * search results for *
  DLF.hadd find.fileserv Found * matches in *:
  DLF.hadd find.fileserv \*\*
  DLF.hadd find.fileserv Use @* to search *
  inc %matches $hget(DLF.find.fileserv,0).item

  if ($hget(DLF.find.headregex)) hfree DLF.find.headregex
  hmake DLF.find.headregex 10
  hadd DLF.find.headregex ^\s*From\s+list\s+(@\S+)\s+found\s+([0-9,]+),\s+displaying\s+([0-9]+):$ 1 2 3
  hadd DLF.find.headregex ^\s*Result.*limit\s+by\s+([0-9,]+)\s+reached\.\s+Download\s+my\s+list\s+for\s+more,\s+by\s+typing\s+(@\S+) 2 0 1
  hadd DLF.find.headregex ^\s*Search\s+Result\W+More\s+than\s+([0-9,]+)\s+Matches\s+For\s+(.*?)\W+Get\s+My\s+List\s+Of\s+[0-9\54]+\s+Files\s+By\s+Typing\s+(@\S+)\s+In\s+The\s+Channel\s+Or\s+Refine\s+Your\s+Search.\s+Sending\s+first\s+([0-9\54]+)\s+Results\W+OmenServe 3 1 4 2
  hadd DLF.find.headregex ^\s*Search\s+Result\W+([0-9\54]+)\s+Matches\s+For\s+(.*?)\s+Get\s+My\s+List\s+Of\s+[0-9\54]+\s+Files\s+By\s+Typing\s+(@\S+)\s+In\s+The\s+Channel\s+Or\s+Refine\s+Your\s+Search.\s+Sending\s+first\s+([0-9\54]+)\s+Results\W+OmenServe 3 1 4 2
  hadd DLF.find.headregex ^\s*Search\s+Result\s+\+\s+More\s+than\s+([0-9\54]+)\s+Matches\s+For\s+(.*?)\s+\+\s+Get\s+My\s+List\s+Of\s+[0-9\54]+\s+Files\s+By\s+Typing\s+(@\S+)\s+In\s+The\s+Channel\s+Or\s+Refine\s+Your\s+Search\.\s+Sending\s+first\s+([0-9\54]+)\s+Results 3 1 4 2
  inc %matches $hget(DLF.find.headregex,0).item

  if ($hget(DLF.find.result)) hfree DLF.find.result
  DLF.hadd find.result !*
  DLF.hadd find.result : !*
  inc %matches $hget(DLF.find.result,0).item

  DLF.StatusAll Added %matches wildcard templates
}

; ========== Status and error messages ==========
alias -l DLF.logo return $rev([dlFilter])
alias -l DLF.StatusAll { scon -a DLF.Status $1- }
alias -l DLF.Status echo -tsf $c(1,9,$DLF.logo $1-)
alias -l DLF.Warning {
  echo -taf $c(1,9,$DLF.logo Warning: $1-)
  DLF.StatusAll Warning: $1-
}
alias -l DLF.Error {
  echo -tabf $c(1,9,$DLF.logo $c(4,$b(Error:)) $1-)
  DLF.StatusAll $c(4,$b(Error:)) $1-
  halt
}
alias -l DLF.Alert {
  var %txt $replace($1-,$crlf,$cr,$lf,$cr), %title %txt
  if ($cr isin %txt) {
    %title = $gettok(%txt,1,$asc($cr))
    %txt = $gettok(%txt,2-,$asc($cr))
  }
  DLF.Watch.Log Alert: %title
  halt $input($replace(%txt,$cr,$crlf),ow,$replace(%title,$cr,$crlf))
}

; $DLF.GitReportsAlert(alert,title,details)
; Returns $false if resulting URL is too long
alias -l DLF.GitReportsAlert {
  if ($0 < 2) DLF.Alert $1
  var %txt $replace($1,$crlf,$cr,$lf,$cr), %title %txt
  if ($cr isin %txt) {
    %title = $gettok(%txt,1,$asc($cr))
    %txt = $gettok(%txt,2-,$asc($cr))
  }
  DLF.Watch.Log GitReportsAlert: %title
  var %url $DLF.GitReports($2,$3), %type oq
  if (%url) %type = yq
  var %yn $input($replace(%txt,$cr,$crlf),%type,$replace(%title,$cr,$crlf))
  if (%yn) {
    if (%url) {
      url -an %url
      DLF.Watch.Log GitReportsAlert: URL loaded: %url
    }
    else DLF.Alert Unable to launch GitReports in your browser window.
  }
  halt
}

; $DLF.GitReports(title,details)
; Returns $false if resulting URL is too long
alias -l DLF.GitReports {
  if ($0 < 1) return $false
  var %url https://gitreports.com/issue/DukeLupus/dlFilter/?
  if ($1 != $null) %url = $+(%url,issue_title=,$urlencode($1))
  if ($2 != $null) %url = $+(%url,&details=,$urlencode($2))
  if ($len(%url) <= 2048) return %url
  echo -s GitReports: URL too long $len(%url)
  DLF.Watch.Log GitReports: URL too long $len(%url)
  return $false

  :error
  DLF.Watch.Log GitReports: Error: $error
  reseterror
  return $false
}

; ========== Utility functions ==========
alias DLF.Run {
  DLF.Watch.Log Executing: run $1-
  run $1-
}

alias -l DLF.chan {
  if ($chan != $null) return $chan
  return Private
}

alias -l DLF.TimerAddress {
  ; Use $address(nick,6) because $address(nick,5) fails if user name is >10 characters
  var %addr $ial($nick)
  if (%addr == $null) %addr = $address($nick,6)
  if (%addr == $null) %addr = $nick
  return %addr
}

alias -l DLF.IsRegularUser {
  if ($1 == $me) {
    DLF.Watch.Log Not regular user: Me
    return $false
  }
  if ($DLF.IsServiceUser($1)) {
    DLF.Watch.Log Not regular user: Services
    return $false
  }
  if ($chan) {
    if (!$DLF.IsRegularUserChan($1,$chan)) return $false
    DLF.Watch.Log Is regular user: $1 in $chan
    return $true
  }
  var %i $comchan($1,0)
  while (%i) {
    var %chan $comchan($1,%i)
    if (!$DLF.IsRegularUserChan($1,%chan)) return $false
    dec %i
  }
  DLF.Watch.Log Is regular user: $1
  return $true
}

alias -l DLF.IsRegularUserChan {
  var %log
  if ($1 isop $2) %log = Op in $2
  elseif ($1 ishop $2) %log = HalfOp in $2
  ; Voice only indicates non-regular user in non-moderated channels
  elseif (($1 isvoice $2) && (m !isin $chan($2).mode)) %log = Voiced in non-moderated $2
  else return $true
  DLF.Watch.Log Not regular user: %log
  return $false
}

alias -l DLF.IsServiceUser {
  if ($1 == BotServ) return $true
  if ($1 == ChanServ) return $true
  if ($1 == GroupServ) return $true
  if ($1 == HelpServ) return $true
  if ($1 == HostServ) return $true
  if ($1 == InfoServ) return $true
  if ($1 == MemoServ) return $true
  if ($1 == NickServ) return $true
  if ($1 == OperServ) return $true
  if ($1 == RootServ) return $true
  if ($1 == TimeServ) return $true
  if ($1 == UserServ) return $true
  if ($1 == WebServ) return $true
  if ($1 == Global) return $true
  return $false
}

alias -l DLF.ComChanOp {
  if ($left($1,1) isin $chantypes) return $false
  var %i $comchan($1,0)
  while (%i) {
    if ($comchan($1,%i).op) return $comchan($1,%i)
    dec %i
  }
  return $false
}

alias -l DLF.GetFileName {
  ; common (OmenServe) response has filename followed by e.g. ::INFO::
  ; and colons are not allowable characters in file names
  var %txt $gettok($replace($strip($1-),$nbsp,$space,$tab $+ $space,$space,$tab,$null),1,$asc(:))
  var %n $numtok(%txt,$asc($space))
  ; delete trailing info: CRC(*) or (*)
  while ($numtok(%txt,$asc($space))) {
    var %last $gettok(%txt,-1,$asc($space))
    if (($+($lbr,*,$rbr) iswm %last) $&
     || ($+(CRC,$lbr,*,$rbr) iswm %last) $&
     || (%last isnum)) %txt = $deltok(%txt,-1,$asc($space))
    else break
  }
  %txt = $noqt(%txt)
  while ($numtok(%txt,$asc(.)) > 1) {
    var %type $gettok($gettok(%txt,-1,$asc(.)),1,$asc($space))
    %txt = $deltok(%txt,-1,$asc(.))
    if (%type isalnum) return $+(%txt,.,%type)
  }
  return $null
}

alias -l DLF.strip { return $replace($strip($1-),$chr(9),$space,$chr(160),$space,$chr(149),$space,$chr(144),$null,$chr(8226),$space,$+($space,$space),$space) }

; ========== mIRC extension identifiers ==========
alias -l IdentifierCalledAsAlias {
  echo $colour(Info) -s * Identifier $+($iif($left($1,1) != $,$),$1) called as alias in $nopath($script)
  halt
}

alias -l trim { return $1- }

alias -l uniquetok {
  if (!$isid) IdentifierCalledAsAlias uniquetok
  var %i $numtok($1,$2)
  if (%i < 2) return $1
  var %tok $1
  while (%i >= 2) {
    var %j %i - 1
    if ($istok($gettok(%tok,$+(1-,%j),$2),$gettok(%tok,%i,$2),$2)) %tok = $deltok(%tok,%i,$2)
    dec %i
  }
  return %tok
}

alias -l min {
  tokenize $asc($space) $1-
  var %i $0
  var %res $1
  while (%i > 1) {
    var %val [ [ $+($,%i) ] ]
    if (%val < %res) %res = %val
    dec %i
  }
  return %res
}

alias -l max {
  tokenize $asc($space) $1-
  var %i $0
  var %res $1
  while (%i > 1) {
    var %val [ [ $+($,%i) ] ]
    if (%val > %res) %res = %val
    dec %i
  }
  return %res
}

alias -l urlencode {
  ; replace $cr $lf $tab $space $comma !#$&'()*+/:;=?@[]`%
  var %s $replacex($1-,$chr(37),$null,$chr(96),$null,$chr(93),$null,$chr(91),$null,$chr(64),$null,$chr(63),$null,$chr(61),$null,$chr(59),$null,$chr(58),$null,$chr(47),$null,$chr(44),$null,$chr(43),$null,$chr(42),$null,$chr(41),$null,$chr(40),$null,$chr(39),$null,$chr(38),$null,$chr(36),$null,$chr(35),$null,$chr(33),$null,$chr(32),$null,$chr(9),$null,$chr(10),$null,$chr(13),$null,$chr(37),$null,$chr(96),$null,$chr(93),$null,$chr(91),$null,$chr(64),$null,$chr(63),$null,$chr(61),$null,$chr(59),$null,$chr(58),$null,$chr(47),$null,$chr(44),$null,$chr(43),$null,$chr(42),$null,$chr(41),$null,$chr(40),$null,$chr(39),$null,$chr(38),$null,$chr(36),$null,$chr(35),$null,$chr(33),$null,$chr(32),$null,$chr(9),$null,$chr(10),$null,$chr(13),$null)
  var %l $len($1-) - $len(%s)
  %l = %l * 3
  %l = %l + $len(%s)
  if (%l > 4146) {
    echo 2 -s * $ $+ urlencode: encoded string will exceed mIRC limit of 4146 characters
    halt
  }
  return $replacex($1-,$chr(37),$+(%,25),$chr(96),$+(%,60),$chr(93),$+(%,5D),$chr(91),$+(%,5B),$chr(64),$+(%,40),$chr(63),$+(%,3F),$chr(61),$+(%,3D),$chr(59),$+(%,3B),$chr(58),$+(%,3A),$chr(47),$+(%,2F),$chr(44),$+(%,2C),$chr(43),$+(%,2B),$chr(42),$+(%,2A),$chr(41),$+(%,29),$chr(40),$+(%,28),$chr(39),$+(%,27),$chr(38),$+(%,26),$chr(36),$+(%,24),$chr(35),$+(%,23),$chr(33),$+(%,21),$chr(32),$+(%,20),$chr(9),$+(%,09),$chr(10),$+(%,0A),$chr(13),$+(%,0D),$chr(37),$+(%,25),$chr(96),$+(%,60),$chr(93),$+(%,5D),$chr(91),$+(%,5B),$chr(64),$+(%,40),$chr(63),$+(%,3F),$chr(61),$+(%,3D),$chr(59),$+(%,3B),$chr(58),$+(%,3A),$chr(47),$+(%,2F),$chr(44),$+(%,2C),$chr(43),$+(%,2B),$chr(42),$+(%,2A),$chr(41),$+(%,29),$chr(40),$+(%,28),$chr(39),$+(%,27),$chr(38),$+(%,26),$chr(36),$+(%,24),$chr(35),$+(%,23),$chr(33),$+(%,21),$chr(32),$+(%,20),$chr(9),$+(%,09),$chr(10),$+(%,0A),$chr(13),$+(%,0D))

  :error
  echo 2 -s * $ $+ urlencode: $error
  halt
}

; Generate and run an identifier call from identifier name, parameters and property
alias -l func {
  if (!$isid) return
  var %p $lower($2)
  var %i 3
  while (%i <= $0) {
    %p = %p $+ , $+ $($+($,%i),2)
    inc %i
  }
  if (%p != $null) {
    %p = $+($,$1,$lbr,%p,$rbr)
    if ($prop) %p = $+(%p,.,$prop)
  }
  else %p = $ $+ $1
  return $(%p,2)
}

; ========== Identifiers instead of $chr(xx) ==========
; Using e.g. $asc($) instead of 36 is more readable
; Identifiers where:
;   $asc doesn't work e.g. $asc(,)
;   character cannot be typed e.g. $tab, $nbsp
;   character is an implied identifier e.g. # = current channel
;   character could be parsed e.g. ( ) { } < > =
alias -l tab returnex $chr(9)
alias -l space returnex $chr(32)
alias -l nbsp return $chr(160)
alias -l hashtag returnex $chr(35)
alias -l lbr return $chr(40)
alias -l rbr return $chr(41)
alias -l comma return $chr(44)
alias -l lt return $chr(60)
alias -l eq return $chr(61)
alias -l gt return $chr(62)
alias -l lcurly return $chr(123)
alias -l rcurly return $chr(125)
alias -l sbr return $+([,$1-,])
alias -l br return $+($lbr,$1-,$rbr)
alias -l tag return $+($lt,$1-,$gt)
alias -l sqt return $+(',$1-,')

; ========== Control Codes using aliases ==========
; Colour, bold, underline, italic, reverse e.g.
; echo 1 This line has $b(bold) $+ , $i(italic) $+ , $u(underscored) $+ , $c(4,red) $+ , and $rev(reversed) text.
; Calls can be nested e.g. echo 1 $c(12,$u(https://github.com/DukeLupus/dlFilter/))
alias -l b return $+($chr(2),$1-,$chr(2))
alias -l u return $+($chr(31),$1-,$chr(31))
alias -l i return $+($chr(29),$1-,$chr(29))
alias -l rev return $+($chr(22),$1-,$chr(22))
alias -l c {
  var %code, %text
  if ($0 < 2) DLF.Error $ $+ c: Insufficient parameters to colour text
  elseif ($1 !isnum 0-15) DLF.Error $ $+ c: Colour value invalid: $1
  elseif (($0 >= 3) && ($2 isnum 0-15)) {
    %code = $+($chr(3),$right(0 $+ $1,2),$comma,$right(0 $+ $2,2))
    %text = $3-
  }
  else {
    %code = $+($chr(3),$right(0 $+ $1,2))
    %text = $2-
  }
  %text = $replace(%text,$chr(15),%code)
  return $+(%code,%text,$chr(15))
}

; ========== Binary file encode/decode ==========
alias -l DLF.CreateBinaryFile {
  if (($0 < 2) || (!$regex($1,/^&[^ ]+$/))) DLF.Error DLF.CreateBinaryFile: Invalid parameters: $1-
  var %len $decode($1,mb)
  if ($decompress($1,b) == 0) DLF.error Error decompressing $2-
  ; Check if file exists and is identical to avoid rewriting it every time
  if ($isfile($2-)) {
    if ($sha256($1,1) == $sha256($2-,2)) {
      DLF.StatusAll Checked file: $2-
      return
    }
  }
  if ($isfile($2-)) {
    .remove $qt($2-)
    DLF.StatusAll Updating file: $2-
  }
  else DLF.StatusAll Creating file: $2-
  if ($exists($2-)) DLF.Error Cannot remove existing $2-
  bwrite -a $qt($2-) -1 -1 $1
  DLF.StatusAll Created file: $2-
}

alias DLF.GenerateBinaryFile {
  if (($0 < 1) || (!$regex($1,/^&[^ ]+$/))) DLF.Error DLF.GenerateBinaryFile: Invalid parameters: $1-
  var %fn $qt($1-)
  ;var %ofn $+(%ifn,.mrc)
  ;if ($isfile(%ofn)) .remove $qt(%ofn)

  bread $qt(%fn) 0 $file(%fn).size &file
  noop $compress(&file,b)
  var %enclen $encode(&file,mb)

  echo 1 $crlf
  echo 1 $rev(To recreate the file, copy and paste the following lines into the mrc script:)
  var %i 1
  while (%i <= %enclen) {
    echo bset -ta &create %i $bvar(&file,%i,60).text
    bset -ta &create %i $bvar(&file,%i,60).text
    if ($bvar(&file,%i,60).text != $bvar(&create,%i,60).text) {
      echo 1 Old: $bvar(&file,1,$bvar(&file,0))
      echo 1 New: $bvar(&create,1,$bvar($create,0))
      DLF.Error DLF.GenerateBinaryFile: Incorrect code generated @ %i !!
    }
    inc %i 60
  }
  echo 1 DLF.CreateBinaryFile & $+ create $1-
  echo 1 $rev(That's all folks!)
}

; ========== ISUPPORT support ==========
; Make 005 responses available for script for e.g.
; Using CPRIVMSG / CNOTICE to avoid ops hitting limits on changing target (of msgs) too frequently
; Sending to @#channel for oNotices
; See http://www.irc.org/tech_docs/draft-brocklesby-irc-isupport-03.txt for 005 definition
; See http://www.irc.org/tech_docs/005.html for parms definitions
alias -l DLF.iSupport.Raw005 {
  ; Remove trailing ":are supported by this server"
  var %new $replace($2-, are supported by this server,$null)
  var %is $DLF.iSupport.Name
  var %old [ [ %is ] ]
  var %n = $numtok(%new,$asc($space)), %i 1
  while (%i <= %n) {
    var %n = $gettok(%new,%i,$asc($space)), %d $left(%n,1)
    if (%d == -) %n = $right(%n,-1)
    var %m %n $+ *
    var %j $wildtok(%old,%m,0,$asc($space))
    while (%j) {
      var %o $wildtok(%old,%m,%j,$asc($space))
      if ((%n == %o) || ($+(%n,=*) iswm %o)) %old = $remtok(%old,%o,0,$asc($space))
      dec %j
    }
    if (%d != -) %old = %old $DLF.iSupport.Decode(%n)
    inc %i
  }
  set -e [ [ %is ] ] $sorttok(%old,$asc($space),a)
}

alias -l DLF.iSupport.Decode {
  return $regsubex(DLF.iSupport.Decode,$1,/(\\x[0-9A-Fa-f]{2})/Fg,$chr($base($right(\t,2),16,10)))
}

alias -l DLF.iSupport.Disconnect {
  unset [ $DLF.iSupport.Name ]
}

alias -l DLF.iSupport.Name { return $+(%,DLF.ISUPPORT.,$network) }

alias -l DLF.iSupport.Supports {
  var %p [ [ $DLF.iSupport.Name ] ]
  var %m $1 $+ *
  var %i $wildtok(%p,%m,0,$asc($space))
  while (%i) {
    var %q $wildtok(%p,%m,%i,$asc($space))
    if ($1 == %q) return $true
    if ($+($1,=*) iswm %q) return $deltok(%q,1,$asc(=))
    dec %i
  }
  return
}

alias -l DLF.msg {
  var %c $DLF.ComChanOp($1)
  if (($DLF.iSupport.Supports(CPRIVMSG)) && (%c) && ($left($1,1) !isin $chantypes)) .raw CPRIVMSG $1 %c $2-
  else .msg $1-
  if ($show) DLF.Win.Echo TextSend Private $1-
}
alias -l DLF.describe {
  .DLF.ctcp $1 Action $2-
  if ($show) DLF.Win.Echo ActionSend Private $1-
}

alias -l DLF.notice {
  var %c $DLF.ComChanOp($1)
  if (($DLF.iSupport.Supports(CNOTICE)) && (%c) && ($left($1,1) !isin $chantypes)) .raw CNOTICE $1 %c $2-
  else .notice $1-
  if ($show) DLF.Win.Echo NoticeSend Private $1-
}

alias -l DLF.ctcp {
  var %c $DLF.ComChanOp($1)
  var %msg $upper($2) $3-
  if (($DLF.iSupport.Supports(CPRIVMSG)) && (%c) && ($left($1,1) !isin $chantypes)) .raw CPRIVMSG $1 %c $DLF.ctcpEncode(%msg)
  else .ctcp $1-
  if ($show) DLF.Win.Echo ctcpSend Private $1-
}

alias -l DLF.ctcpreply {
  var %c $DLF.ComChanOp($1)
  if (($DLF.iSupport.Supports(CNOTICE)) && (%c) && ($left($1,1) !isin $chantypes)) .raw CNOTICE $1 %c $DLF.ctcpEncode($2-)
  else .ctcpreply $1-
  if ($show) DLF.Win.Echo ctcpreplySend Private $1-
}

alias -l DLF.ctcpEncode {
  var %s $replacex($1-,$chr(16),$+($chr(16),$chr(16)),$chr(0),$+($chr(16),$chr(48)),$chr(10),$+($chr(16),$chr(110)),$chr(13),$+($chr(16),$chr(114)))
  return $+($chr(1),%s,$chr(1))
}

; ========== mIRC Options ==========
; Get mIRC options not available through a standard identifier
alias -l prefixown return $DLF.mIRCini(options,0,23)
alias -l showmodeprefix return $DLF.mIRCini(options,2,30)
alias -l enablenickcolors return $DLF.mIRCini(options,0,32)
alias -l shortjoinsparts return $DLF.mIRCini(options,2,19)
alias -l windowbuffer return $DLF.mIRCini(options,3,1)
alias -l usesinglemsg return $DLF.mIRCini(options,0,22)

alias -l DLF.mIRCini {
  var %item $2
  if ($2 isnum) %item = n $+ $2
  var %ini $readini($mircini,n,$1,%item)
  if ($3 == $null) return %ini
  return $gettok(%ini,$3,$asc($comma))
}

; ========== DLF.Watch.* ==========
; Routines to help developers by providing a filtered debug window
menu @dlF.Watch.* {
  Search: DLF.Search.Show $menu $?="Enter search string"
  -
  Clear: clear
  Options: DLF.Options.Show
  Disable: debug -c off
  -
}

alias DLF.Watch {
  if ((($0 == 0) && ($debug)) || ($1- == off)) debug off
  else {
    if (($0 == 0) || ($1 == on)) {
      var %target @dlF.Watch. $+ $network
      if ($window(%target) == $null) {
        window -k0mx %target
        titlebar %target -=- Watch irc messages on $network and dlF's handling of them.
      }
    }
    else var %target $qt($1-)
    debug -ipt %target DLF.Watch.Filter
  }
}

alias DLF.Watch.Filter {
  ; This identifier should return $1- if it is a line dlF reacts to else $null
  ; In practice this means returning $null iff it is a channel message and not a dlF channel.
  var %text $1-
  tokenize $asc($space)) $1-
  if ($left($2,1) == :) {
    var %user $right($2,-1)
    tokenize $asc($space)) $1 $3-
  }
  if ($1 == ->) {
    var %server $2
    tokenize $asc($space)) $1 $3-
  }
  if (($2 == PING) || ($2 == PONG)) return $null
  DLF.Watch.Log %text
  return $null
}

alias -l DLF.Watch.Called {
  if ($event == $null) var %event User action
  elseif ($event isnum) var %event RAW $event
  else var %event ON $upper($event)
  var %msg
  if ($2-) %msg = : $2-
  DLF.Watch.Log %event called $1 $+ %msg
}

; If user has scrolled up from the bottom of custom window, mIRC does not delete excess lines
; Since user can leave these windows scrolled up, they would grow uncontrollably unless we prune them manually.
alias -l DLF.Win.CustomTrim {
  if ($window($1).type !isin custom listbox) return
  var %buf $windowbuffer
  var %max %buf * 1.2
  var %del %buf * 1.1
  var %del $line($1,0) - $int(%del)
  if ($line($1,0) >= %max) dline $1 $+(1-,%del)
}

alias -l DLF.Watch.Log {
  if ($debug == $null) return
  if ($0 == 0) return
  if ($left($debug,1) != @) write $debug $1-
  else {
    DLF.Win.CustomTrim $debug
    var %c 3
    if ($1 == <-) %c = 1
    elseif ($1 == ->) %c = 12
    elseif ($1 == Halted:) %c = 4
    if ($1 isin <->) DLF.Watch.Offset
    var %l $timestamp $+ $DLF.Watch.Offset $1-
    DLF.Search.Add $debug 1 %c %l
    aline -pi %c $debug %l
  }
}

; /DLF.Watch.Offset : reset ms offset
; $DLF.Watch.Offset : returns 3-digit +ms offset value
alias -l DLF.Watch.Offset {
  var %ticks $ticks
  if (!$var(%DLF.offsetticks,0) || (!$isid)) {
    set -e %DLF.offsetticks %ticks
    if (!$isid) return
  }
  var %ticks %ticks - %DLF.offsetticks
  %ticks = %ticks % 1000
  return + $+ $base(%ticks,10,10,3)
}

alias -l DLF.Halt {
  if ($0) DLF.Watch.Log $1-
  else DLF.Watch.Log Halted: No details available
  halt
}

alias -l DLF.Watch.Unload { scon -a debug -c off }

; ========== DLF.Debug ==========
; Run this with /DLF.Debug only if you are asked to
; by someone providing dlFilter support.
alias DLF.Debug {
  var %file $qt($+($sysdir(downloads),dlFilter.debug.txt))
  echo 14 -s [dlFilter] Debug started.
  if ($show) echo 14 -s [dlFilter] Creating %file
  write -c %file --- Start of debug info --- $logstamp ---
  write -i %file
  write %file Executing $script from $scriptdir
  write %file dlFilter version %DLF.version
  write %file mIRC version $version $iif($portable,portable)
  write %file Running Windows $os
  write %file Host: $host
  write %file IP: $ip
  write -i %file
  write -i %file
  var %cs $scon(0)
  if ($show) echo 14 -s [dlFilter] %cs servers
  write %file --- Servers --- %cs servers
  write -i %file
  var %i 1
  while (%i <= %cs) {
    var %st $scon(%i).status
    if (%st == connected) %st = $iif($scon(%i).ssl,securely) %st to $+($scon(%i).server,$chr(40),$scon(%i).serverip,:,$scon(%i).port,$chr(41)) as $scon(%i).me
    if ($show) echo 14 -s [dlFilter] Server %i is $scon(%i).servertarget $+ : %st
    write %file Server %i is $scon(%i).servertarget $+ : %st
    if (%st != disconnected) {
      write %file $chr(9) ChanTypes= $+ $scon(%i).chantypes $+ , ChanModes= $+ [ $+ $scon(%i).chanmodes $+ ], Modespl= $+ $scon(%i).modespl $+ , Nickmode= $+ $scon(%i).nickmode $+ , Usermode= $+ $scon(%i).usermode
      scon %i
      var %nochans $chan(0), %chans $null
      while (%nochans) {
        if ($chan(%nochans).cid == $cid) %chans = $addtok(%chans,$chan(%nochans) $+([,$chan(%nochans).mode,]),44)
        dec %nochans
      }
      scon -r
      %chans = $sorttok(%chans,44)
      write %file $chr(9) Channels: $replace(%chans,$chr(44),$chr(44) $+ $chr(32))
    }
    inc %i
  }
  write -i %file
  write -i %file
  var %scripts $script(0)
  if ($show) echo 14 -s [dlFilter] %scripts scripts loaded
  write %file --- Scripts --- %scripts scripts loaded
  write -i %file
  var %i 1
  while (%i <= %scripts) {
    if ($show) echo 14 -s [dlFilter] Script %i is $script(%i)
    write %file Script %i is $script(%i) and is $lines($script(%i)) lines and $file($script(%i)).size bytes
    inc %i
  }
  write -i %file
  write -i %file
  var %vars $var(*,0)
  var %DLFvars $var(DLF.*,0)
  if ($show) echo 14 -s [dlFilter] Found %vars variables, of which %DLFvars are dlFilter variables.
  write %file --- dlFilter Variables --- %vars variables, of which %DLFvars are dlFilter variables.
  write -i %file
  var %vars
  while (%DLFvars) {
    %vars = $addtok(%vars,$var(DLF.*,%DLFvars),44)
    dec %DLFvars
  }
  var %vars $sorttok(%vars,44,r)
  var %DLFvars $numtok(%vars,44)
  while (%DLFvars) {
    var %v $gettok(%vars,%DLFvars,44)
    write %file %v = $var($right(%v,-1),1).value
    dec %DLFvars
  }
  write -i %file
  write -i %file
  var %grps $group(0)
  if ($show) echo 14 -s [dlFilter] %grps group(s) found
  write %file --- Groups --- %grps group(s) found
  write -i %file
  var %i 1
  while (%i <= %grps) {
    write %file Group %i $iif($group(%i).status == on,on: $+ $chr(160),off:) $group(%i) from $group(%i).fname
    inc %i
  }
  write -i %file
  write -i %file
  var %hs $hget(0)
  if ($show) echo 14 -s [dlFilter] %hs hash table(s) found
  write %file --- Hash tables --- %hs hash table(s) found
  write -i %file
  var %i 1
  while (%i <= %hs) {
    write %file Table %i $+ : $hget(%i) $+ , items $hget(%i, 0).item $+ , slots $hget(%i).size
    inc %i
  }
  write -i %file
  write %file --- End of debug info --- $logstamp ---
  echo 14 -s [dlFilter] Debug ended.
}
