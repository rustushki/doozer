doozer
------
by Russ Adams

Introduction
------------

Doozer is a simple plugin for Vim to aid in multi-project building.  It builds
a project based on configuration directives in your vimrc.  Before building the
specified project, it will first build any dependency projects.

Features
--------

- Project building.
- Project dependency duilding.
- Cluster building (grouping of projects).
- Project build by current buffer.
- Ad-hoc, non-build project targets and shell commands.
- Simple Syntax
- Asynchronous Builds (Neovim only)

Example
-------

The following example declares 1 cluster which is made up of 3 projects.  The
TicTacToe project has two dependencies.

    set makeprg=make               " Set the Make Program
    
    CluName "MyGames"              " Start a New Cluster called 'MyGames'
    CluRoot "~/Source/MyGames"     " Base directory for other project directories.
    CluTarget "clean", "clean"     " All Projects in this cluster have a target called 'clean'
    
    PrjName "TicTacToe"            " Start a Project called 'TicTacToe'
    PrjRoot "TicTacToe"            " It's directory is ~/Source/MyGames/TicTacToe
    PrjTarget "build", ""          " The build target runs 'make' (with no make target)
	PrjTarget "compile", ""        " Just like 'build', but dependencies not built.
	PrjTarget "sfix", "spritefix"  " 'spritefix' is a shell command to be run.
    PrjDep    "GfxLibrary"         " It has two dependency projects which must be built first.
    PrjDep    "AI"
    PrjSave                        " Save the project
    
    PrjName "GfxLibrary"           " Start a Project called 'GfxLibrary'
    PrjRoot "GfxLibrary"           " It's directory is ~/Source/MyGames/GfxLibrary
    PrjTarget "build", "prj"       " The build target runs 'make prj'
    PrjTarget "clean", "specClean" " Override default 'clean' target. Runs 'make specClean'
    PrjSave                        " Save the project
    
    PrjName "AI"                   " Start a Project called 'AI' 
    PrjRoot "AI"                   " It's directory is ~/Source/MyGames/AI
    PrjTarget "build" ""           " The build target runs 'make' (with no make target)
    PrjSave                        " Save the project
    
    CluSave                        " Save the cluster.

Now you can do neat things right from Vim.

    :PrjDoTarget "AI", "build"          " Builds the AI Project.
    :PrjDoTarget "TicTacToe", "build"   " Builds AI, GfxLibrary and finally TicTacToe.
    :PrjDoTarget "TicTacToe", "compile" " Builds TicTacToe, but no dependencies.
	:PrjDoCommand "TicTacToe", "sfix"   " Runs a special command specified by the 'sfix' target.
	:PrjDoTarget "GfxLibrary", "clean"  " Cleans GfxLibrary.

In each case, the project's target is executed in a shell from Vim.  If there
are build errors, it will open the QuickFix window.

More useful than the above commands are these two:

    :DoTargetFromBuffer "compile"
    :DoCommandFromBuffer "sfix"

Each of these directives will run the associated build target or shell command
on the project associated with the file in the current buffer.  This is very
powerful because it allows you to setup shortcuts like these:


    noremap <Leader>b :DoTargetFromBuffer  "build"<CR>
    noremap <Leader>c :DoTargetFromBuffer  "compile"<CR>
    noremap <Leader>s :DoCommandFromBuffer "sfix"<CR>

I use this everyday, I hope you enjoy it.
