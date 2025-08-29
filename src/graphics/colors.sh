# Reset color
declare -r RESET='\033[0m'

# Basic Colors (30-37)
declare -r BLACK='\033[0;30m'
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r MAGENTA='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[0;37m'

# Bold Colors (1;30-37)
declare -r BOLD_BLACK='\033[1;30m'
declare -r BOLD_RED='\033[1;31m'
declare -r BOLD_GREEN='\033[1;32m'
declare -r BOLD_YELLOW='\033[1;33m'
declare -r BOLD_BLUE='\033[1;34m'
declare -r BOLD_MAGENTA='\033[1;35m'
declare -r BOLD_CYAN='\033[1;36m'
declare -r BOLD_WHITE='\033[1;37m'

# Underlined Colors (4;30-37)
declare -r UNDERLINE_BLACK='\033[4;30m'
declare -r UNDERLINE_RED='\033[4;31m'
declare -r UNDERLINE_GREEN='\033[4;32m'
declare -r UNDERLINE_YELLOW='\033[4;33m'
declare -r UNDERLINE_BLUE='\033[4;34m'
declare -r UNDERLINE_MAGENTA='\033[4;35m'
declare -r UNDERLINE_CYAN='\033[4;36m'
declare -r UNDERLINE_WHITE='\033[4;37m'

# Background Colors (40-47)
declare -r BG_BLACK='\033[40m'
declare -r BG_RED='\033[41m'
declare -r BG_GREEN='\033[42m'
declare -r BG_YELLOW='\033[43m'
declare -r BG_BLUE='\033[44m'
declare -r BG_MAGENTA='\033[45m'
declare -r BG_CYAN='\033[46m'
declare -r BG_WHITE='\033[47m'

# Bright Colors (90-97)
declare -r BRIGHT_BLACK='\033[0;90m'
declare -r BRIGHT_RED='\033[0;91m'
declare -r BRIGHT_GREEN='\033[0;92m'
declare -r BRIGHT_YELLOW='\033[0;93m'
declare -r BRIGHT_BLUE='\033[0;94m'
declare -r BRIGHT_MAGENTA='\033[0;95m'
declare -r BRIGHT_CYAN='\033[0;96m'
declare -r BRIGHT_WHITE='\033[0;97m'

# Bright Background Colors (100-107)
declare -r BG_BRIGHT_BLACK='\033[100m'
declare -r BG_BRIGHT_RED='\033[101m'
declare -r BG_BRIGHT_GREEN='\033[102m'
declare -r BG_BRIGHT_YELLOW='\033[103m'
declare -r BG_BRIGHT_BLUE='\033[104m'
declare -r BG_BRIGHT_MAGENTA='\033[105m'
declare -r BG_BRIGHT_CYAN='\033[106m'
declare -r BG_BRIGHT_WHITE='\033[107m'

# Text Formatting
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r ITALIC='\033[3m'
declare -r UNDERLINE='\033[4m'
declare -r BLINK='\033[5m'
declare -r REVERSE='\033[7m'
declare -r STRIKETHROUGH='\033[9m'

# Extended 256-color palette (some popular ones)
declare -r ORANGE='\033[38;5;208m'
declare -r PURPLE='\033[38;5;129m'
declare -r PINK='\033[38;5;205m'
declare -r BROWN='\033[38;5;94m'
declare -r GRAY='\033[38;5;244m'
declare -r GREY='\033[38;5;244m'
declare -r LIGHT_GRAY='\033[38;5;250m'
declare -r LIGHT_GREY='\033[38;5;250m'
declare -r DARK_GRAY='\033[38;5;236m'
declare -r DARK_GREY='\033[38;5;236m'

# RGB True Color examples (24-bit color support)
declare -r CRIMSON='\033[38;2;220;20;60m'
declare -r LIME='\033[38;2;50;205;50m'
declare -r GOLD='\033[38;2;255;215;0m'
declare -r NAVY='\033[38;2;0;0;128m'
declare -r TEAL='\033[38;2;0;128;128m'
declare -r OLIVE='\033[38;2;128;128;0m'
declare -r MAROON='\033[38;2;128;0;0m'
declare -r SILVER='\033[38;2;192;192;192m'
