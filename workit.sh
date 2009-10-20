# Functions to load working code projects
#
# heavily influenced/copied from Doug Hellmanns, virtualenvwrapper
# http://bitbucket.org/dhellmann/virtualenvwrapper/overview/
#
# set -x

# TODO
# virtualenv sets the VIRTUAL_ENV system variable, need to replicate a bit
source ~/projects/workit/process_functions.sh

# You can override this setting in your .zshrc
if [ "$WORKIT_HOME" = "" ]
then
	WORKIT_HOME=( "$HOME/src" "$HOME/configs" )
	export WORKIT_HOME
fi

# Normalize the directory name in case it includes 
# relative path components.
# this broke hard for some reason so forget normalizing for now. 
# it's probably some sort of subshell thing again, but 
# for now just leave it be and look it up later
# for ((i=1;i<=${#WORKIT_HOME};i++)); do
#     rpath=$WORKIT_HOME[$i]
#     echo $rpath
#     WORKIT_HOME[$i]=$(/bin/zsh -c 'cd "$rpath"; pwd')
# done
# export WORKIT_HOME

### Functions

# Verify that the WORKON_HOME directory exists
function verify_workit_home () {
    for zpath in $WORKIT_HOME; do
        if [ ! -d "$zpath" ]
        then
            echo "ERROR: projects directory '$zpath' does not exist." >&2
            return 1
        fi
    done
    return 0
}

# Verify that the requested project exists
function verify_workit_project () {
    typeset env_name="$1"

    for zpath in $WORKIT_HOME; do
        if [ -d "$zpath/$env_name" ]
        then
            echo "$zpath/$env_name"
            return 0
        fi
    done

    return 1
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
function mkworkit () {
    verify_workit_home || return 1

    workit_home_count=${#WORKIT_HOME}

    if [ $workit_home_count -eq 1 ]
    then
        path_idx=1
        ARGS=1  # only 1 arg needed, <projname>
    else
        ARGS=3  # 3 args, -p <x> <projname>
    fi

    if [ $# -ne "$ARGS" ]
    then
        echo "Usage: mkworkit -p <x> <projectname>"
        show_workit_home_options
        return 65
    fi

    # must have > 1 WORKIT_HOME defined
    # so grab the -p value
    if [ $workit_home_count -gt 1 ]
    then
        while getopts "p:" par; do
            case $par in
                (p) path_idx=$OPTARG;;
                (?) exit 1;;
            esac
        done

        shift $(( OPTIND -1 ))
    fi

    eval "projname=\$$#"

    # test if the path_idx is a valid index less than the length of the
    # WORKIT_HOME
    max_index=${#WORKIT_HOME}
    if [ "$path_idx" -gt "$max_index" ] 
    then
        echo "The -p path index must be a valid integer from the list of paths below"
        show_workit_home_options
        return 65
    fi

    proj_path=$WORKIT_HOME[$path_idx]

    (cd "$proj_path" &&
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
    [ ! -d "$proj_path/$envname" ] && return 0
    workit "$projname"
    #workit_source_hook "$WORKIT_HOME/postmkvirtualenv"
}

# List the available environments.
function show_workit_projects () {
    verify_workit_home || return 1
    # NOTE: DO NOT use ls here because colorized versions spew control characters
    #       into the output list.
    all=()
    for ((i=1;i<=${#WORKIT_HOME};i++)); do
        dirs=$( cd "$WORKIT_HOME[$i]"; for f in *; do [[ -d $f ]] && echo $f; done )
        all+=("\n\n$dirs")
    done
    echo $all
}

# list the available workit home directories for adding a new project to
function show_workit_home_options () {
    verify_workit_home || return 1
    for ((i=1;i<=${#WORKIT_HOME};i++)); do
        proj=${WORKIT_HOME[$i]}
        echo "$i - $proj"
    done
}

# List or change workit projects
#
# Usage: workit [environment_name]
#
function workit () {
	typeset PROJ_NAME="$1"

	PROJ_PATH=$( verify_workit_project "$PROJ_NAME" )
    if [ ! -d $PROJ_PATH ]
    then
        return 1
    else
        export PROJ_PATH
    fi

	if [ "$PROJ_NAME" = "" ]
    then
        show_workit_projects
        return 1
    fi

    verify_workit_home || return 1

    # Deactivate any current environment "destructively"
    # before switching so we use our override function,
    # if it exists.
    type deactivate >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        deactivate
    fi
    
    cd $PROJ_PATH

    # Save the deactivate function from virtualenv
    # virtualenvwrapper_saved_deactivate=$(typeset -f deactivate)

    # Replace the deactivate() function with a wrapper.
    eval 'function deactivate () {
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
        workit_source_hook "postdeactivate"
    }'
    
    workit_source_hook "postactivate"
#    workit_source_hook "$project/postactivate"    
    
	return 0
}

#
# Set up tab completion.  (Adapted from Arthur Koziel's version at 
# http://arthurkoziel.com/2008/10/11/virtualenvwrapper-bash-completion/)
# 
compctl -g "`show_workit_projects`" workit 
