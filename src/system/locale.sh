#!/usr/bin/env bash

# Function: locale_setup
# Description: Configures the system locale by installing the necessary locale
#              package, generating the locale, and setting it as the default via
#              environment variables. Auto-detects the package manager.
#
# Arguments:
#   --locale LOCALE (string, optional, default: "en_US.UTF-8"): The locale to
#       configure (e.g. "de_DE.UTF-8", "fr_FR.UTF-8").
#   --dry-run (flag, optional): Print the commands that would be executed without
#       running them. Defaults to IS_DRY_RUN if not specified.
#
# Globals:
#   IS_DRY_RUN (read): When "true", enables dry-run mode by default.
#
# Returns:
#   0 - Locale configured successfully.
#   1 - Invalid arguments, unsupported package manager, or locale generation failed.
#
# Examples:
#   locale_setup
#   locale_setup --locale "de_DE.UTF-8"
#   locale_setup --locale "fr_FR.UTF-8" --dry-run
locale_setup() {
    local locale="en_US.UTF-8"
    local dry_run="${IS_DRY_RUN:-false}"

    while (( "$#" )); do
        case "$1" in
            --locale)
                if [[ -z "$2" || "$2" == --* ]]; then
                    error "Missing value for --locale"
                    return 1
                fi
                locale="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    local lang="${locale%%.*}"
    local encoding="${locale##*.}"
    local encoding_lower
    encoding_lower="$(echo "$encoding" | tr '[:upper:]' '[:lower:]' | tr -d '-')"

    info "Setting up locale: $locale"

    if command -v apt &>/dev/null; then
        _locale_setup_apt "$locale" "$lang" "$encoding_lower" "$dry_run"
    elif command -v dnf &>/dev/null; then
        _locale_setup_dnf "$locale" "$lang" "$dry_run"
    elif command -v yum &>/dev/null; then
        _locale_setup_yum "$locale" "$lang" "$dry_run"
    elif command -v pacman &>/dev/null; then
        _locale_setup_pacman "$locale" "$lang" "$encoding" "$dry_run"
    elif command -v apk &>/dev/null; then
        _locale_setup_apk "$locale" "$dry_run"
    elif command -v zypper &>/dev/null; then
        _locale_setup_zypper "$locale" "$lang" "$dry_run"
    else
        error "Could not determine the package manager. Cannot configure locale."
        return 1
    fi
}

_locale_setup_apt() {
    local locale="$1" lang="$2" encoding_lower="$3" dry_run="$4"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] apt install -y locales"
        info "[dry-run] sed -i 's/^# *${locale}/${locale}/' /etc/locale.gen"
        info "[dry-run] locale-gen"
        info "[dry-run] update-locale LANG=${locale}"
        return 0
    fi

    apt update > >(log_output) 2>&1
    apt install -y locales > >(log_output) 2>&1 || {
        error "Failed to install locales package."
        return 1
    }

    sed -i "s/^# *\(${lang}\.${encoding_lower}\)/\1/" /etc/locale.gen 2>/dev/null
    sed -i "s/^# *\(${locale}\)/\1/" /etc/locale.gen 2>/dev/null

    locale-gen > >(log_output) 2>&1 || {
        error "locale-gen failed."
        return 1
    }

    update-locale LANG="$locale" > >(log_output) 2>&1
    _locale_export "$locale"
    info "Locale $locale configured successfully."
}

_locale_setup_dnf() {
    local locale="$1" lang="$2" dry_run="$3"
    local langpack="glibc-langpack-${lang%%_*}"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] dnf install -y ${langpack}"
        info "[dry-run] localectl set-locale LANG=${locale}"
        return 0
    fi

    dnf install -y "$langpack" > >(log_output) 2>&1 || {
        error "Failed to install ${langpack}."
        return 1
    }

    if command -v localectl &>/dev/null; then
        localectl set-locale LANG="$locale" > >(log_output) 2>&1
    fi

    _locale_export "$locale"
    info "Locale $locale configured successfully."
}

_locale_setup_yum() {
    local locale="$1" lang="$2" dry_run="$3"
    local langpack="glibc-langpack-${lang%%_*}"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] yum install -y ${langpack}"
        info "[dry-run] localectl set-locale LANG=${locale}"
        return 0
    fi

    yum install -y "$langpack" > >(log_output) 2>&1 || {
        error "Failed to install ${langpack}."
        return 1
    }

    if command -v localectl &>/dev/null; then
        localectl set-locale LANG="$locale" > >(log_output) 2>&1
    fi

    _locale_export "$locale"
    info "Locale $locale configured successfully."
}

_locale_setup_pacman() {
    local locale="$1" lang="$2" encoding="$3" dry_run="$4"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] sed -i 's/^#${locale}/${locale}/' /etc/locale.gen"
        info "[dry-run] locale-gen"
        info "[dry-run] echo 'LANG=${locale}' > /etc/locale.conf"
        return 0
    fi

    sed -i "s/^#\(${locale}\)/\1/" /etc/locale.gen 2>/dev/null || {
        error "Failed to uncomment ${locale} in /etc/locale.gen."
        return 1
    }

    locale-gen > >(log_output) 2>&1 || {
        error "locale-gen failed."
        return 1
    }

    echo "LANG=${locale}" > /etc/locale.conf

    _locale_export "$locale"
    info "Locale $locale configured successfully."
}

_locale_setup_apk() {
    local locale="$1" dry_run="$2"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] export LANG=${locale}"
        info "[dry-run] export LC_ALL=${locale}"
        info "[dry-run] echo 'export LANG=${locale}' >> /etc/profile.d/locale.sh"
        return 0
    fi

    # Alpine uses musl which has limited locale support.
    # Install musl-locales if available for better support.
    if apk info -e musl-locales &>/dev/null || apk search musl-locales 2>/dev/null | grep -q musl-locales; then
        apk add --no-cache musl-locales > >(log_output) 2>&1
    fi

    mkdir -p /etc/profile.d
    cat > /etc/profile.d/locale.sh <<EOF
export LANG=${locale}
export LC_ALL=${locale}
EOF

    _locale_export "$locale"
    info "Locale $locale configured successfully (Alpine has limited locale support via musl)."
}

_locale_setup_zypper() {
    local locale="$1" lang="$2" dry_run="$3"
    local langpack="glibc-locale"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] zypper install -y ${langpack}"
        info "[dry-run] localectl set-locale LANG=${locale}"
        return 0
    fi

    zypper install -y "$langpack" > >(log_output) 2>&1 || {
        error "Failed to install ${langpack}."
        return 1
    }

    if command -v localectl &>/dev/null; then
        localectl set-locale LANG="$locale" > >(log_output) 2>&1
    fi

    _locale_export "$locale"
    info "Locale $locale configured successfully."
}

_locale_export() {
    local locale="$1"
    export LANG="$locale"
    export LC_ALL="$locale"
}
