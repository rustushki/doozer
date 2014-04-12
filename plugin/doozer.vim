let s:clusters = []
let s:doozerBufName = "[doozer]"
let s:doozerWinShowing = 0

autocmd VimEnter * call s:Setup()

" Project / Cluster Configuration {{{1
" CluName {{{2
" Start editing a new Cluster.  Will overwrite any unsaved Cluster.
command! -nargs=? CluName call CluName(<args>)
func! CluName(cluName)
	let s:curClu = {}
	let s:curClu.name = a:cluName
	let s:curClu.root = ""
	let s:curClu.projects = []
    let s:curClu.targets = {}
endfunc

" CluRoot {{{2
" Sets the Root Folder for all projects in the Cluster.  This is an optional
" field.
command! -nargs=? CluRoot call CluRoot(<args>)
func! CluRoot(cluRoot)
	let s:curClu.root = a:cluRoot
endfunc

" CluTarget {{{2
" Adds a default target to the cluster with the given action.  Cluster targets
" are inherited by all projects inside the cluster (unless overriden by a
" project's target of the same name).
command! -nargs=? CluTarget call CluTarget(<args>)
func! CluTarget(cluTargetName, cluTargetAction)
	let s:curClu.targets[a:cluTargetName] = a:cluTargetAction
endfunc

" CluSave {{{2
" Adds the Cluster Record currently edited to the list of clusters.  The
" Cluster will no longer be editable after this command.
command! CluSave call CluSave()
func! CluSave()
	let s:clusters += [s:curClu]
	let s:curClu = {}
endfunc

" PrjName {{{2
" Start adding a project to the current cluster being edited.
command! -nargs=? PrjName call PrjName(<args>)
func! PrjName(prjName)
	let s:curPrj = {}
	let s:curPrj.name = a:prjName
    let s:curPrj.targets = {}
	let s:curPrj.deps = []
    let s:curPrj.cluParent = s:curClu
endfunc

" PrjRoot {{{2
" Set the root folder (relative to the parent cluster) of the project
" currently edited.  This folder is the directory from which all targets will
" be executed.
command! -nargs=? PrjRoot call PrjRoot(<args>)
func! PrjRoot(prjRoot)
	let l:actualRoot = s:curClu.root . '/' . a:prjRoot
	let s:curPrj.root = fnamemodify(l:actualRoot, ":p")
endfunc

" PrjTarget {{{2
" Add a target with its command to the currently edited project.
command! -nargs=? PrjTarget call PrjTarget(<args>)
func! PrjTarget(prjTargetName, prjTargetAction)
	let s:curPrj.targets[a:prjTargetName] = a:prjTargetAction
endfunc

" PrjDep {{{2
" Add a dependency project to the current project.  The special 'build' target
" will cause the dependency project to have its build target executed first.
command! -nargs=? PrjDep call PrjDep(<args>)
func! PrjDep(prjDep)
	let s:curPrj.deps += [a:prjDep]
endfunc

" PrjSave {{{2
" Add the project to the currently edited cluster.  The project is no longer
" editable.
command! PrjSave call PrjSave()
func! PrjSave()
	let s:curClu.projects += [s:curPrj]
    let s:curPrj = {}
endfunc

" User Commands {{{1
" DoTargetFromBuffer {{{2
" Given a target, find the matching project of the current buffer and execute
" the target.
command! -nargs=? DoTargetFromBuffer call DoTargetFromBuffer(<args>)
func! DoTargetFromBuffer(target)
	let l:prjRecs = s:GetProjectRecordByRoot(expand('%:h'))
	if !empty(l:prjRecs)
		let l:name = l:prjRecs[0].name
		call PrjDoTarget(l:name, a:target)
    else
        echo "Could not find project for current buffer."
	endif
endfunc

" DoCommandFromBuffer {{{2
" Given a command target, find the matching project of the current buffer and
" execute the target.
command! -nargs=? DoCommandFromBuffer call DoCommandFromBuffer(<args>)
func! DoCommandFromBuffer(target)
	let l:prjRecs = s:GetProjectRecordByRoot(expand('%:h'))
	if !empty(l:prjRecs)
		let l:name = l:prjRecs[0].name
		call PrjDoCommand(l:name, a:target)
    else
        echo "Could not find project for current buffer."
	endif
endfunc

" PrjDoTarget {{{2
command! -nargs=? PrjDoTarget call PrjDoTarget(<args>)
func! PrjDoTarget(name, target)
	" Determine the Build Order.
	let l:buildOrder = s:GetBuildOrder(a:name, a:target, [])

	" For each project in the Build Order, concatenate the target action
	" command to the command string for that project.
    for l:prjName in l:buildOrder
        call s:DoTarget(l:prjName, a:target, 0)

        if s:CountBuildErrors() != 0
            break
        endif
    endfor

	" Open QuickFix window if any problems.
    cwindow

	" Force Redraw the screen
    execute "redraw!"
endfunc

" PrjDoCommand {{{2
" Given a project name and target name, shell execute the target's action.
command! -nargs=? PrjDoCommand call PrjDoCommand(<args>)
func! PrjDoCommand(name, target)
    call s:DoTarget(a:name, a:target, 1)
endfunc

" CluDoTarget {{{2
" Given a Cluster Name and a Target, attempt to execute that target on all
" projects in the cluster.
command! -nargs=? CluDoTarget call CluDoTarget(<args>)
func! CluDoTarget(cluName, target)
	" Initialize the list of targeted projects
	let l:targetedProjects = []

	" Find the Cluster
	let l:cluster = s:GetClusterByName(a:cluName)

	" If the Cluster exists, target each of its projects.
	if l:cluster != {}
		for l:project in l:cluster.projects
			let l:targetedProjects = add(l:targetedProjects, l:project.name)
		endfor
	endif

    " Build the specified target for each of the cluster's projects.
    let l:mergedBuildOrder = []
	for l:projectName in l:targetedProjects
		" Determine the Build Order.
		let l:buildOrder = s:GetBuildOrder(l:projectName, a:target, [])
        let l:mergedBuildOrder = s:MergeBuildOrder(l:mergedBuildOrder, l:buildOrder)
	endfor

    " For each project in the Build Order, concatenate the target action
    " command to the command string for that project.
    for l:prjName in l:mergedBuildOrder
        "echom l:prjName
        call s:DoTarget(l:prjName, a:target, 0)

        " Stop building if any errors.
        if s:CountBuildErrors() != 0
            break
        endif
    endfor

	" Open QuickFix window if any problems.
    cwindow

	" Force Redraw the screen
    execute "redraw!"
endfunc

" ShowDoozer {{{2
func! ShowDoozer()
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
" GetClusterByName {{{2
" Given a Cluster Name, return the Cluster Record.
func! s:GetClusterByName(cluName)
	for l:cluster in s:clusters
		if l:cluster.name == a:cluName
			return l:cluster
		endif
	endfor

	return {}
endfunc
" GetBuildOrder {{{2
" Given a Project Name, a Target and a pre-populated list of Projects, append
" to the list of Projects a Build Order of Projects required to run the target
" for the provided Project Name.  Note:  The special 'build' target actually
" examines Project Dependencies.  Other targets do not and will cause this
" function to return a list containing only the provided project.
func! s:GetBuildOrder(name, target, buildOrder)
	let l:buildOrder = a:buildOrder

	" Build Order only works with the special 'build' target.
	if a:target == "build"
		let l:prjRec = s:GetProjectRecordByName(a:name)
		if l:prjRec != {}
			for l:prjDep in l:prjRec.deps
				if index(l:buildOrder, l:prjDep) < 0
					let l:buildOrder = s:GetBuildOrder(l:prjDep, a:target, l:buildOrder) 
				endif
			endfor
		endif
	endif

	" Lastly, add the provided project to the build order.
	return add(l:buildOrder, a:name)
endfunc

" MergeBuildOrder
" Given two build orders, merge the second into the first, ensuring that each
" project is only built once.  Return the merged build order.
func! s:MergeBuildOrder(sortedBuildOrder, buildOrder)
    " Copy the sorted build order argument so we can modify it.
    let l:mergedBuildOrder = a:sortedBuildOrder

    " For each project in the provided build order, check the merged build
    " order list for it. If it's not in there, add it.
    for l:prjName in a:buildOrder
        if index(l:mergedBuildOrder, l:prjName) == -1
            let l:mergedBuildOrder = add(l:mergedBuildOrder, l:prjName)
        endif
    endfor

    " Return the properly merged build order.
    return l:mergedBuildOrder
endfunc
" GetProjectRecordByName {{{2

func! s:GetProjectRecordByName(prjName)
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

" GetProjectRecordByRoot {{{2

" Given a path, find the projects which contain this path.
" TODO: Does not support the idea of subprojects. (i.e. a project which
" contains another project inside its directory tree.
"
" TODO: Does not support the idea of multiple projects with the same root.
func! s:GetProjectRecordByRoot(path)
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

" ExecuteCmd {{{2
" Given a shell command, execute it.  Prefer Dispatch if its available,
" otherwise, just shell escape and execute the command.
func! s:ExecuteCmd(cmd)
	" Select a runner.
	" Use vim-dispatch if its available, otherwise use the standard 'bang' to
	" shell execute the command.
	let l:runner = "!"
	if exists(":Dispatch")
		let l:runner = "silent! Dispatch"
	endif

	" Build the Project
	exec l:runner . " " . a:cmd
endfunc

" DoTarget {{{2
" Given a project name, target and whether the target is a command or not: cd
" to the project root and execute the target.
func! s:DoTarget(prjName, target, isCommand)
    " Fetch the project record
    let l:prjRec = s:GetProjectRecordByName(a:prjName)

    " Fetch the Target Action
    let l:targetAction = s:GetTargetAction(l:prjRec, a:target)

    " Build the target if it exists.
    if l:targetAction != ""
        " cd to the project
        let l:origDir = getcwd()
        execute 'cd ' . l:prjRec.root

        " Do the target as a build target or command depending on the
        " isCommand flag.
        let l:executor = ""
        if a:isCommand
            let l:executor = '!'
        else
            let l:executor = 'silent! make'
        endif

        " Run the target action.
        execute l:executor . ' ' . l:targetAction

        " cd back to the original directory.
        execute 'cd ' . l:origDir
    endif
endfunc

" GetTargetAction {{{2
func! s:GetTargetAction(prjRec, target)
    if has_key(a:prjRec.targets, a:target)
        return a:prjRec.targets[a:target]
    elseif has_key(a:prjRec.cluParent.targets, a:target)
        return a:prjRec.cluParent.targets[a:target]
    endif

    return ""
endfunc

" CountBuildErrors {{{2
func! s:CountBuildErrors()
    let l:count = 0

    for l:qfrec in getqflist()
        if l:qfrec.bufnr != 0
            let l:count += 1
        endif
    endfor

    return l:count
endfunc

" Setup {{{2
func! s:Setup()
	augroup doozer
		autocmd BufWinLeave \[doozer\] call s:Cleanup()
	augroup END
endfunc

" Cleanup {{{2
func! s:Cleanup()
	let s:doozerWinShowing = 0
endfunc

" vim:ft=vim foldmethod=marker sw=4
