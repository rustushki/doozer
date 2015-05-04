let s:clusters = []
let s:doozerBufName = "[doozer]"
let s:doozerWinShowing = 0

autocmd VimEnter * call doozer#lib#setup()

" Project / Cluster Configuration {{{1
" doozer#lib#cluname {{{2
" Start editing a new Cluster.  Will overwrite any unsaved Cluster.
func! doozer#lib#cluname(cluName)
	let s:curClu = {}
	let s:curClu.name = a:cluName
	let s:curClu.root = ""
	let s:curClu.projects = []
	let s:curClu.targets = {}
endfunc

" doozer#lib#cluroot {{{2
" Sets the Root Folder for all projects in the Cluster.  This is an optional
" field.
func! doozer#lib#cluroot(cluRoot)
	let s:curClu.root = a:cluRoot
endfunc

" doozer#lib#clutarget {{{2
" Adds a default target to the cluster with the given action.  Cluster targets
" are inherited by all projects inside the cluster (unless overriden by a
" project's target of the same name).
func! doozer#lib#clutarget(cluTargetName, cluTargetAction)
	let s:curClu.targets[a:cluTargetName] = a:cluTargetAction
endfunc

" doozer#lib#clusave {{{2
" Adds the Cluster Record currently edited to the list of clusters.  The
" Cluster will no longer be editable after this command.
func! doozer#lib#clusave()
	let s:clusters += [s:curClu]
	let s:curClu = {}
endfunc

" doozer#lib#prjname {{{2
" Start adding a project to the current cluster being edited.
func! doozer#lib#prjname(prjName)
	let s:curPrj = {}
	let s:curPrj.name = a:prjName
	let s:curPrj.targets = {}
	let s:curPrj.deps = []
	let s:curPrj.cluParent = s:curClu
endfunc

" doozer#lib#prjroot {{{2
" Set the root folder (relative to the parent cluster) of the project
" currently edited.  This folder is the directory from which all targets will
" be executed.
func! doozer#lib#prjroot(prjRoot)
	let l:actualRoot = s:curClu.root . '/' . a:prjRoot
	let s:curPrj.root = fnamemodify(l:actualRoot, ":p")
endfunc

" doozer#lib#prjtarget {{{2
" Add a target with its command to the currently edited project.
func! doozer#lib#prjtarget(prjTargetName, prjTargetAction)
	let s:curPrj.targets[a:prjTargetName] = a:prjTargetAction
endfunc

" doozer#lib#prjdep {{{2
" Add a dependency project to the current project.  The special 'build' target
" will cause the dependency project to have its build target executed first.
func! doozer#lib#prjdep(prjDep)
	let s:curPrj.deps += [a:prjDep]
endfunc

" doozer#lib#prjsave {{{2
" Add the project to the currently edited cluster.  The project is no longer
" editable.
func! doozer#lib#prjsave()
	let s:curClu.projects += [s:curPrj]
	let s:curPrj = {}
endfunc

" User Commands {{{1
" doozer#lib#doTargetFromBuffer {{{2
" Given a target, find the matching project of the current buffer and execute
" the target.
func! doozer#lib#doTargetFromBuffer(target)
	let l:prjRecs = doozer#lib#getProjectRecordByRoot(expand('%:h'))
	if !empty(l:prjRecs)
		let l:name = l:prjRecs[0].name
		call doozer#lib#prjDoTarget(l:name, a:target)
	else
		echo "Could not find project for current buffer."
	endif
endfunc

" doozer#lib#doCommandFromBuffer {{{2
" Given a command target, find the matching project of the current buffer and
" execute the target.
func! doozer#lib#doCommandFromBuffer(target)
	let l:prjRecs = doozer#lib#getProjectRecordByRoot(expand('%:h'))
	if !empty(l:prjRecs)
		let l:name = l:prjRecs[0].name
		call doozer#lib#prjDoCommand(l:name, a:target)
	else
		echo "Could not find project for current buffer."
	endif
endfunc

" doozer#lib#prjDoTarget {{{2
func! doozer#lib#prjDoTarget(name, target)
	" Determine the Build Order.
	let l:buildOrder = doozer#lib#getBuildOrder(a:name, a:target, [])

	" Queue each project in the build order for later execution.
	for l:prjRec in l:buildOrder
		let l:targetAction = doozer#lib#getTargetAction(l:prjRec, a:target)
		call doozer#build#queue(l:prjRec.name, l:targetAction, l:prjRec.root, 0)
	endfor

	call doozer#build#execQueue()

	" Open QuickFix window if any problems.
	cwindow

	" Force Redraw the screen
	execute "redraw!"
endfunc

" doozer#lib#prjDoCommand {{{2
" Given a project name and target name, shell execute the target's action.
func! doozer#lib#prjDoCommand(name, target)
	let l:prjRec = doozer#lib#getProjectRecordByName(a:name)
	let l:targetAction = doozer#lib#getTargetAction(l:prjRec, a:target)
	call doozer#build#queue(l:prjRec.name, l:targetAction, l:prjRec.root, 1)
	call doozer#build#execQueue()
endfunc

" doozer#lib#cluDoTarget {{{2
" Given a Cluster Name and a Target, attempt to execute that target on all
" projects in the cluster.
func! doozer#lib#cluDoTarget(cluName, target)
	" Initialize the list of targeted projects
	let l:targetedProjects = []

	" Find the Cluster
	let l:cluster = doozer#lib#getClusterByName(a:cluName)

	" If the Cluster exists, target each of its projects.
	if l:cluster != {}
		for l:project in l:cluster.projects
			let l:targetedProjects = add(l:targetedProjects, l:project.name)
		endfor
	endif

	" Build the specified target for each of the cluster's projects.
	let l:mergedBuildOrder = []
	for l:prjName in l:targetedProjects
		" Determine the Build Order.
		let l:buildOrder = doozer#lib#getBuildOrder(l:prjName, a:target, [])
		let l:mergedBuildOrder = doozer#lib#mergeBuildOrder(l:mergedBuildOrder, l:buildOrder)
	endfor

	" Queue each project in the build order for later execution.
	for l:prjRec in l:mergedBuildOrder
		let l:targetAction = doozer#lib#getTargetAction(l:prjRec, a:target)
		call doozer#build#queue(l:prjRec.name, l:targetAction, l:prjRec.root, 0)
	endfor

	" Execute the projects in order.
	call doozer#build#execQueue()

	" Open QuickFix window if any problems.
	cwindow

	" Force Redraw the screen
	execute "redraw!"
endfunc

" show {{{2
func! doozer#lib#show()
	" Go to the Doozer buffer if it exists already.
	if s:doozerWinShowing == 1
		execute 'drop ' . s:doozerBufName

		" Otherwise, make a new one.
	else
		30vnew
		execute "silent keepjumps hide edit " . s:doozerBufName
		setlocal buftype=nofile
		setlocal noswapfile
		setlocal nowrap

		let s:doozerWinShowing = 1
	endif

	setlocal nonumber
	setlocal modifiable

	" Clear the buffer.
	%delete

	" Build a list of projects.
	let l:lines = []
	for l:cluRec in s:clusters
		for l:prjRec in l:cluRec.projects
			call add(l:lines, l:prjRec.name)
		endfor
	endfor

	" Add the List to the Buffer.
	call setline(1, l:lines)

	setlocal nomodifiable
endfunc

" Script Local Helper Methods {{{1
" doozer#lib#getClusterByName {{{2
" Given a Cluster Name, return the Cluster Record.
func! doozer#lib#getClusterByName(cluName)
	for l:cluster in s:clusters
		if l:cluster.name == a:cluName
			return l:cluster
		endif
	endfor

	return {}
endfunc

" doozer#lib#getBuildOrder {{{2
" Given a Project Name, a Target and a pre-populated list of Projects, append
" to the list of Projects a Build Order of Projects required to run the target
" for the provided Project Name.  Note:  The special 'build' target actually
" examines Project Dependencies.  Other targets do not and will cause this
" function to return a list containing only the provided project.
func! doozer#lib#getBuildOrder(name, target, buildOrder)
	let l:buildOrder = a:buildOrder
	let l:prjRec = doozer#lib#getProjectRecordByName(a:name)

	if l:prjRec != {}
		" Build Order only works with the special 'build' target.
		if a:target == "build"
			for l:prjDep in l:prjRec.deps
				if index(l:buildOrder, l:prjDep) < 0
					let l:buildOrder = doozer#lib#getBuildOrder(l:prjDep, a:target, l:buildOrder) 
				endif
			endfor
		endif

		" Lastly, add the provided project to the build order.
		call add(l:buildOrder, l:prjRec)
	endif

	return l:buildOrder
endfunc

" doozer#lib#mergeBuildOrder
" Given two build orders, merge the second into the first, ensuring that each
" project is only built once.  Return the merged build order.
func! doozer#lib#mergeBuildOrder(sortedBuildOrder, buildOrder)
	" Copy the sorted build order argument so we can modify it.
	let l:mergedBuildOrder = a:sortedBuildOrder

	" For each project in the provided build order, check the merged build
	" order list for it. If it's not in there, add it.
	for l:prjRec in a:buildOrder
		if index(l:mergedBuildOrder, l:prjRec) == -1
			let l:mergedBuildOrder = add(l:mergedBuildOrder, l:prjRec)
		endif
	endfor

	" Return the properly merged build order.
	return l:mergedBuildOrder
endfunc
"
" doozer#lib#getProjectRecordByName {{{2
func! doozer#lib#getProjectRecordByName(prjName)
	for l:cluRec in s:clusters
		let l:projects = l:cluRec.projects
		for l:prjRec in l:projects
			if l:prjRec.name == a:prjName
				return l:prjRec
			endif
		endfor
	endfor

	return {}
endfunc

" doozer#lib#getProjectRecordByRoot {{{2
" Given a path, find the projects which contain this path.
" TODO: Does not support the idea of subprojects. (i.e. a project which
" contains another project inside its directory tree.
"
" TODO: Does not support the idea of multiple projects with the same root.
func! doozer#lib#getProjectRecordByRoot(path)
	" Get Full Path of the Provided Path
	let l:path = fnamemodify(a:path, ":p")

	" Build a list of Project Records which would contain the path provided.
	let l:prjMatching = []
	for l:cluRec in s:clusters
		let l:projects = l:cluRec.projects
		for l:prjRec in l:projects
			if match(l:path, l:prjRec.root) == 0
				let l:prjMatching += [l:prjRec]
			endif
		endfor
	endfor

	return l:prjMatching
endfunc

" doozer#lib#getTargetAction {{{2
func! doozer#lib#getTargetAction(prjRec, target)
	if has_key(a:prjRec.targets, a:target)
		return a:prjRec.targets[a:target]
	elseif has_key(a:prjRec.cluParent.targets, a:target)
		return a:prjRec.cluParent.targets[a:target]
	endif

	return ""
endfunc

" doozer#lib#setup {{{2
func! doozer#lib#setup()
	augroup doozer
		autocmd BufWinLeave \[doozer\] call doozer#lib#cleanup()
	augroup END
endfunc

" doozer#lib#cleanup {{{2
func! doozer#lib#cleanup()
	let s:doozerWinShowing = 0
endfunc

" vim:ft=vim foldmethod=marker sw=4
