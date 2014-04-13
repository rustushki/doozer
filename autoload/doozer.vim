command! -nargs=? CluName             call doozer#lib#cluname(<args>)
command! -nargs=? CluRoot             call doozer#lib#cluroot(<args>)
command! -nargs=? CluTarget           call doozer#lib#clutarget(<args>)
command! -nargs=0 CluSave             call doozer#lib#clusave()
command! -nargs=? PrjName             call doozer#lib#prjname(<args>)
command! -nargs=? PrjRoot             call doozer#lib#prjroot(<args>)
command! -nargs=? PrjTarget           call doozer#lib#prjtarget(<args>)
command! -nargs=? PrjDep              call doozer#lib#prjdep(<args>)
command! -nargs=0 PrjSave             call doozer#lib#prjsave()
command! -nargs=? DoTargetFromBuffer  call doozer#lib#doTargetFromBuffer(<args>)
command! -nargs=? DoCommandFromBuffer call doozer#lib#doCommandFromBuffer(<args>)
command! -nargs=? PrjDoTarget         call doozer#lib#prjDoTarget(<args>)
command! -nargs=? PrjDoCommand        call doozer#lib#prjDoCommand(<args>)
command! -nargs=? CluDoTarget         call doozer#lib#cluDoTarget(<args>)

func! doozer#rc(...) abort
	" Do nothing.
endfunc
