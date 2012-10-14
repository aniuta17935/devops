#
# common rerun functions
#


# __Colorizing functions__

# Unset `RERUN_COLOR` to disable.
txtrst () { tput sgr0 ; }
bold() { echo -e "\033[1m$*\033[0m" ; txtrst ; }
dim() { tput dim ; echo " $*" ; txtrst ; }
[ -n "$RERUN_COLOR" ] && {
    ul="\033[4m" ; _ul="\033[0m" ; # underline
    gray="\033[38;5;238m" ; _gray="\033[0m" ; # gray
    red="\033[31m" ; _red="\033[0m" ; # red
    bold="\033[1m$*\033[0m" ; _bold="\033[0m" ; # bold
}


# Print the message and exit.
# Use text effects if `RERUN_COLOR` environment variable set.
rerun_die() {
    if [[ "$RERUN_COLOR" == "true" ]]
    then echo >&2 -e ${red}"ERROR: $*"${_red} 
    else echo >&2 "ERROR: $*" 
    fi
    exit 1
}

# print USAGE and exit
rerun_option_error() {
    if [[ "$RERUN_COLOR" == "true" ]]
    then echo >&2 -e ${red}"SYNTAX: $*"${_red} 
    else echo >&2 "SYNTAX: $*" 
    fi
    exit 2
}

# check option has its argument
rerun_option_check() {
    [ "$1" -lt 2 ] && {
        rerun_option_error "option requires argument: $2"
    }
}

# print USAGE and exit
rerun_option_usage() {
    if [ -f $0 ]
    then grep '^#/ usage:' <"$0" | cut -c4- >&2
    else echo >&2 "usage: check command for usage." 
    fi
    return 2
}

# Bootstrap a command handler
rerun_init() {
    # Shell modules reside in current directory, by default. 
    homedir=$(dirname .)
    # Use env var property if it exists otherwise set it to default.
    [ -n "$RERUN_MODULES" ] || RERUN_MODULES=$homedir/modules    
}

rerun_modules() {
    names=
    for f in `echo $1/*/metadata`; do
	[ -f $f ] && {
		mod_name=$(basename $(dirname $f))
		names="$names $mod_name"
	}
    done
    echo $names
}

rerun_commands() {
    commands=
    for c in `echo $1/$2/commands/*/default.sh`; do
	[ -f $c ] && {
	    cmd_name=$(basename $(dirname $c))
	    commands="$commands $cmd_name"
	}
    done
    echo $commands
}

rerun_options() {
    options=
    for o in `echo $1/$2/commands/$3/*.option`; do
	[ -f $o ] && {
	    opt_def=$(basename $o)
	    opt_name=${opt_def%.option}
	    options="$options $opt_name"
	}
    done
    echo $options
}

rerun_optionArguments() {
	[ -f $1/$2/commands/$3/$4.option ] && {
		awk -F= '/ARGUMENTS/ {print $2}' $1/$2/commands/$3/$4.option
	}
}

rerun_optionDefault() {
	[ -f $1/$2/commands/$3/$4.option ] && {
    	awk -F= '/DEFAULT/ {print $2}' $1/$2/commands/$3/$4.option
	}
}

rerun_optionShort() {
	[ -f $1/$2/commands/$3/$4.option ] && {
    	awk -F= '/SHORT/ {print $2}' $1/$2/commands/$3/$4.option
	}
}

rerun_optionRequired() {
	[ -f $1/$2/commands/$3/$4.option ] && {
    	awk -F= '/REQUIRED/ {print $2}' $1/$2/commands/$3/$4.option
	}
}
rerun_optionExported() {
	[ -f $1/$2/commands/$3/$4.option ] && {
    	awk -F= '/EXPORT/ {print $2}' $1/$2/commands/$3/$4.option
	}
}

rerun_testDescription() {
	[ -f $1/$2/tests/commands/$3/metadata ] && {
		awk -F= '/DESCRIPTION/ {print $2}' $1/$2/tests/commands/$3/metadata
	}
}
rerun_commandDescription() {
	[ -f $1/$2/commands/$3/metadata ] && {
		awk -F= '/DESCRIPTION/ {print $2}' $1/$2/commands/$3/metadata
	}
}

rerun_absolutePath() {
    local infile="${1:-$0}"
    {
        if [[ "${infile#/}" = "${infile}" ]]; then
            echo $(pwd)/${infile}
        else
            echo ${infile}
        fi
    } | sed '
    :a
    s;/\./;/;g
    s;//;/;g
    s;/[^/][^/]*/\.\./;/;g
    ta'
}

optionsWithDefaults() {
    local moddir=$1 module=$2 command=$3

    local optionsWithDefaults=""
    for opt in $(rerun_options $moddir $module $command); do
        default=$(rerun_optionDefault $moddir $module $command $opt)
        args=$(rerun_optionArguments $moddir $module $command $opt)
        [ -n "$default" -a "$args" == "true" ] && optionsWithDefaults="$optionsWithDefaults $opt"
    done
    echo $optionsWithDefaults
}

# list the options that are required
optionsRequired() {
    local moddir=$1 module=$2 command=$3
    local optionsRequired=""

    for opt in $(rerun_options $moddir $module $command); do
        required=$(rerun_optionRequired $moddir $module $command $opt)
        args=$(rerun_optionArguments $moddir $module $command $opt)
        [ "$required" == "true" -a "$args" = "true" ] && optionsRequired="$optionsRequired $opt"
    done
    echo $optionsRequired
}
# list the options that are exported as environment variables
optionsExported() {
    local moddir=$1 module=$2 command=$3
    local optionsExported=""

    for opt in $(rerun_options $moddir $module $command); do
        exported=$(rerun_optionExported $moddir $module $command $opt)
        [ "$exported" == "true" ] && optionsExported="$optionsExported $opt"
    done
    echo $optionsExported
}

# Upper case the string and change dashes to underscores.
trops() { echo "$1" | tr '[:lower:]' '[:upper:]' | tr  '-' '_' ; }

# Used to generate an entry inside options.sh
add_optionparser() {
	local optName=$1
    local optVarname=$(trops $optName)
	local ARGUMENTS=$(rerun_optionArguments $moddir $module $command $optName)
	local SHORT=$(rerun_optionShort $moddir $module $command $optName)
	if [ -n "${SHORT}" ] 
	then
		argstring=$(printf ' --%s|-%s' "${optName}"  "${SHORT}")
	else
		argstring=$(printf " --%s" "${optName}" )
    fi
	if [ "$ARGUMENTS" == "false" ]
	then
		printf " %s) %s=true ;;\n" "${argstring}" "$optVarname"
	else
    	printf " %s) rerun_option_check \$# ; %s=\$2 ; shift ;;\n" \
			"$argstring" "$optVarname"
	fi
}

add_commandUsage() {
    [ $# = 3 ] || { echo >&2 "usage add_commandUsage <moddir> <module> <command>" ; return 1 ; }
    local moddir=$1 module=$2 command=$3

    for opt in $(rerun_options $moddir $module $command); do
        [ -f $moddir/$module/commands/${command}/${opt}.option ] || continue
        (
            local usage=
            source  $moddir/$module/commands/${command}/${opt}.option
		    if [ -n "${SHORT}" ] 
		    then
			    argstring=$(printf ' --%s|-%s' "${NAME}" "${SHORT}")
		    else
			    argstring=$(printf " --%s" "${NAME}" )
		    fi		  
		    [ "true" == "${ARGUMENTS}" ] && {
			    argstring=$(printf "%s <%s>" "$argstring" "${DEFAULT}")
		    }
		    [ "true" != "${REQUIRED}" ] && {
			    usage=$(printf "[%s]" "${argstring}") 
		    } || {
			    usage=$(printf "%s" "${argstring}")
		    }
            printf "%s " "$usage"
        )
    done
}

# Generate option parser script.
rerun_generateOptionsParser() {
    [ $# = 3 ] || { 
        echo >&2 "usage add_generateOptionsParser <moddir> <module> <command>" 
        return 1 ; 
    }
    local moddir=$1 module=$2 command=$3

    # list the options that set a default
    local optionsWithDefaults=$(optionsWithDefaults $RERUN_MODULES $MODULE $COMMAND)

    # list the options that are required
    local optionsRequired=$(optionsRequired $RERUN_MODULES $MODULE $COMMAND)

    # list the options that have variables to export
    local optionsExported=$(optionsExported $RERUN_MODULES $MODULE $COMMAND)

    (
        cat <<EOF
# Generated by stubbs:add-option. Do not edit, if using stubbs.
# Created: $(date)
#
#/ usage: $module:$command $(add_commandUsage $moddir $module $command)

# print USAGE and exit
rerun_option_usage() {
    grep '^#/ usage:' <"\$0" | cut -c4- >&2
    return 2
}

# print SYNTAX and exit
rerun_option_error() {
    if [[ "\$RERUN_COLOR" == "true" ]]
    then echo >&2 -e "${red}""SYNTAX: \$*""${_red}"
    else echo >&2 "SYNTAX: \$*" 
    fi
    exit 2
}

# check option has its argument
rerun_option_check() {
    [ "\$1" -lt 2 ] && rerun_option_usage
}

# options: [$(rerun_options $moddir $module $command)]
while [ "\$#" -gt 0 ]; do
    OPT="\$1"
    case "\$OPT" in
$(for o in $(rerun_options $moddir $module $command); do 
printf "      %s\n" "$(add_optionparser $o)"; 
done)
        # help option
        -?)
            rerun_option_usage
            exit 2
            ;;
        # end of options, just arguments left
        *)
          break
    esac
    shift
done

# If defaultable options variables are unset, set them to their DEFAULT
$(for opt in $(echo $optionsWithDefaults|sort); do
printf "[ -z \"$%s\" ] && %s=\"%s\"\n" $(trops $opt) $(trops $opt) $(rerun_optionDefault $moddir $module $command $opt)
done)
# Check required options are set
$(for opt in $(echo $optionsRequired|sort); do
printf "[ -z \"$%s\" ] && { echo >&2 \"missing required option: --%s\" ; return 2 ; }\n" $(trops $opt) $opt
done)
# If option variables are declared exportable, export them.
$(for opt in $(echo $optionsExported|sort); do
printf "export %s\n" $(trops $opt)
done)
#
return 0
EOF
    ) 
    # generated to stdout
}

list_optionVariables() {
    [ $# = 3 ] || { 
        echo >&2 "usage list_optionVariables <moddir> <module> <command>" 
        return 1 ; 
    }
    local moddir=$1 module=$2 command=$3
    local summary=
    for option in $(rerun_options $moddir $module $command); do
        summary="$summary $(trops $option)"
    done
    echo $summary
}

rerun_rewriteCommandScriptHeader() {
    [ $# = 3 ] || { 
        echo >&2 "usage rerun_rewriteCommandScriptHeader <moddir> <module> <command>" 
        return 1 ; 
    }
    local moddir=$1 module=$2 command=$3
    local desc=$(rerun_commandDescription $moddir $module $command)
    local variables=$(list_optionVariables $moddir $module $command) || rerun_die
    local usage=$(add_commandUsage $moddir $module $command) || rerun_die
    local commandScript=$moddir/$module/commands/$command/default.sh
    [ ! -f "$commandScript" ] && {
        rerun_die "command script not found: $commandScript"
    }
    sed "
        s,#/ command: .*,#/ command: $module:$command: \"$desc\",
        s,#/ variables: .*,#/ variables: $variables,
        s,#/ usage: .*,#/ usage: rerun $module:$command $usage,
        " $commandScript 
    # generated to stdout
}
