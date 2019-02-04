while [ "$#" -ne 0 ]; do
    ARG="$1"
    shift # get rid of $1, we saved in ARG already
    case "$ARG" in
      --logon-password) 
            echo "LOGON $1" 
            shift 
        ;;
      --info) echo "Cosas" ;;
      * | --help) echo "Possible commands: create, clean, all, check, install, run, prepare, stop, stash" ;;
    esac
done
