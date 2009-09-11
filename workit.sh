# Functions to load working code projects
#
# heavily influenced/copied from Doug Hellmanns, virtualenvwrapper
# http://bitbucket.org/dhellmann/virtualenvwrapper/overview/
#

# TODO
# virtualenv sets the VIRTUAL_ENV system variable, need to replicate a bit
source ~/src/workit/process_functions.sh

# You can override this setting in your .zshrc
if [ "$WORKIT_HOME" = "" ]
then
    export WORKIT_HOME="$HOME/src"
fi

# Normalize the directory name in case it includes 
# relative path components.
WORKIT_HOME=$(sh -c 'cd "$WORKIT_HOME"; pwd')
export WORKIT_HOME

### Functions

# Verify that the WORKON_HOME directory exists
function verify_workit_home () {
    if [ ! -d "$WORKIT_HOME" ]
    then
        echo "ERROR: projects directory '$WORKIT_HOME' does not exist." >&2
        return 1
    fi
    return 0
}

# Verify that the requested project exists
function verify_workit_project () {
    typeset env_name="$1"
    if [ ! -d "$WORKIT_HOME/$env_name" ]
    then
       echo "ERROR: Project '$env_name' does not exist. Create it with 'mkproj $env_name'." >&2
       return 1
    fi
    return 0
}

# Verify that the active project exists
function verify_active_project () {
    if [ ! -n "${PROJECT_DIR}" ] || [ ! -d "${PROJECT_DIR}" ]
    then
        echo "ERROR: no project active, or active project is missing" >&2
        return 1
    fi
    return 0
}

# source the pre/post hooks
function workit_source_hook () {
    scriptname="$1"
    
    if [ -f "$scriptname" ]
    then
        source "$scriptname"
    fi
}


# run the pre/post hooks
function workit_run_hook () {
    scriptname="$1"
    shift
    if [ -x "$scriptname" ]
    then
        "$scriptname" "$@"
    fi
}

# Create a new project, in the WORKIT_HOME.
#
# Usage: mkworkit [options] PROJNAME
#
function mkworkit () {
    if [ $# -eq 0 ]  # Must have command-line args to demo script.
    then
      echo "Please supply a project name"
      exit 65
    fi

    eval "projname=\$$#"
    verify_workit_home || return 1
    (cd "$WORKIT_HOME" &&
        mkdir $projname &&
        touch "$projname/postactivate" &&
        touch "$projname/postdeactivate" &&
        chmod +x "$projname/postactivate" "$projname/postdeactivate" 

        # skip the hook for now
        # && 
        # workit_run_hook "./premkvirtualenv" "$envname"
        )
    # If they passed a help option or got an error from virtualenv,
    # the environment won't exist.  Use that to tell whether
    # we should switch to the environment and run the hook.
    [ ! -d "$WORKIT_HOME/$envname" ] && return 0
    workit "$envname"
    # workit_source_hook "$WORKIT_HOME/postmkvirtualenv"
}

# List the available environments.
function show_workit_projects () {
    verify_workit_home || return 1
    # NOTE: DO NOT use ls here because colorized versions spew control characters
    #       into the output list.
    (cd "$WORKIT_HOME"; for f in *; do [[ -d $f ]] && echo $f; done) | sed 's|^\./||' | sort
}

# List or change workit projects
#
# Usage: workit [environment_name]
#
function workit () {
	typeset PROJ_NAME="$1"
	typeset PROJ_PATH="$WORKIT_HOME/$PROJ_NAME"

	if [ "$PROJ_NAME" = "" ]
    then
        show_workit_projects
        return 1
    fi

    verify_workit_home || return 1
    verify_workit_project $PROJ_NAME || return 1

    cd $PROJ_PATH
    
    # Deactivate any current environment "destructively"
    # before switching so we use our override function,
    # if it exists.
    # type deactivate >/dev/null 2>&1
    # if [ $? -eq 0 ]
    # then
    #     deactivate
    # fi
    
    # Save the deactivate function from virtualenv
    # virtualenvwrapper_saved_deactivate=$(typeset -f deactivate)

    # Replace the deactivate() function with a wrapper.
    # eval 'function deactivate () {
    #     # Call the local hook before the global so we can undo
    #     # any settings made by the local postactivate first.
    #     virtualenvwrapper_source_hook "$VIRTUAL_ENV/bin/predeactivate"
    #     virtualenvwrapper_source_hook "$WORKON_HOME/predeactivate"
    #     
    #     env_postdeactivate_hook="$VIRTUAL_ENV/bin/postdeactivate"
    #     
    #     # Restore the original definition of deactivate
    #     eval "$virtualenvwrapper_saved_deactivate"

    #     # Instead of recursing, this calls the now restored original function.
    #     deactivate

    #     virtualenvwrapper_source_hook "$env_postdeactivate_hook"
    #     virtualenvwrapper_source_hook "$WORKON_HOME/postdeactivate"
    # }'
    
    workit_source_hook "postactivate"
#    workit_source_hook "$project/postactivate"    
    
	return 0
}

#
# Set up tab completion.  (Adapted from Arthur Koziel's version at 
# http://arthurkoziel.com/2008/10/11/virtualenvwrapper-bash-completion/)
# 
compctl -g "`show_workit_projects`" workit 
