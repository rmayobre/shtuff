#!/usr/bin/env bash

# Function: service
# Description: Generates a systemd service unit file with the specified configuration.
#
# Arguments:
#   --name NAME (string, required): Service name; .service extension is appended automatically if omitted.
#   --description DESC (string, required): Human-readable description written to the [Unit] section.
#   --exec-start COMMAND (string, required): Full command used to start the service.
#   --working-directory DIR (string, optional): Working directory set for the service process.
#   --user USER (string, optional): System user the service process runs as.
#   --group GROUP (string, optional): System group the service process runs as.
#   --restart POLICY (string, optional, default: on-failure): Systemd restart policy.
#   --restart-sec SECONDS (integer, optional, default: 5): Seconds to wait before restarting.
#   --wanted-by TARGET (string, optional, default: multi-user.target): Systemd install target.
#   --environment ENV (string, optional): Space-separated VAR=value pairs added as Environment= directives.
#   --exec-start-pre COMMAND (string, optional): Command to run before ExecStart.
#   --exec-stop COMMAND (string, optional): Command to run when stopping the service.
#   --output-dir DIR (string, optional, default: /etc/systemd/system): Directory to write the unit file into.
#   -n NAME (string, required): Short form of --name.
#   -d DESC (string, required): Short form of --description.
#   -e COMMAND (string, required): Short form of --exec-start.
#   -w DIR (string, optional): Short form of --working-directory.
#   -u USER (string, optional): Short form of --user.
#   -g GROUP (string, optional): Short form of --group.
#   -r POLICY (string, optional): Short form of --restart.
#   -o DIR (string, optional): Short form of --output-dir.
#
# Globals:
#   None
#
# Returns:
#   0 - Service unit file created successfully.
#   1 - Required argument missing or unknown option provided.
#
# Examples:
#   service \
#       --name "myapp" \
#       --description "My Web Application" \
#       --exec-start "/usr/bin/node /opt/myapp/server.js" \
#       --user "www-data" \
#       --working-directory "/opt/myapp"
#
#   service \
#       --name "api-server" \
#       --description "API Server" \
#       --exec-start "/usr/local/bin/api-server" \
#       --user "apiuser" \
#       --environment "PORT=8080 NODE_ENV=production" \
#       --restart "always"
service() {
    local service_name=""
    local description=""
    local exec_start=""
    local working_directory=""
    local user=""
    local group=""
    local restart="on-failure"
    local restart_sec="5"
    local wanted_by="multi-user.target"
    local environment=""
    local exec_start_pre=""
    local exec_stop=""
    local output_dir="/etc/systemd/system"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                service_name="$2"
                shift 2
                ;;
            -d|--description)
                description="$2"
                shift 2
                ;;
            -e|--exec-start)
                exec_start="$2"
                shift 2
                ;;
            -w|--working-directory)
                working_directory="$2"
                shift 2
                ;;
            -u|--user)
                user="$2"
                shift 2
                ;;
            -g|--group)
                group="$2"
                shift 2
                ;;
            -r|--restart)
                restart="$2"
                shift 2
                ;;
            --restart-sec)
                restart_sec="$2"
                shift 2
                ;;
            --wanted-by)
                wanted_by="$2"
                shift 2
                ;;
            --environment)
                environment="$2"
                shift 2
                ;;
            --exec-start-pre)
                exec_start_pre="$2"
                shift 2
                ;;
            --exec-stop)
                exec_stop="$2"
                shift 2
                ;;
            -o|--output-dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$service_name" ]]; then
        error "Error: Service name is required (use -n or --name)" >&2
        return 1
    fi

    if [[ -z "$description" ]]; then
        error "Error: Service description is required (use -d or --description)" >&2
        return 1
    fi

    if [[ -z "$exec_start" ]]; then
        error "Error: ExecStart command is required (use -e or --exec-start)" >&2
        return 1
    fi

    # Ensure service name ends with .service
    if [[ "$service_name" != *.service ]]; then
        service_name="${service_name}.service"
    fi

    local service_file="${output_dir}/${service_name}"

    info "Creating service file: $service_file"

    # Create the service file content
    cat > "$service_file" << EOF
[Unit]
Description=$description
After=network.target

[Service]
Type=simple
ExecStart=$exec_start
Restart=$restart
RestartSec=${restart_sec}s
EOF

    # Add optional parameters if provided
    if [[ -n "$working_directory" ]]; then
        echo "WorkingDirectory=$working_directory" >> "$service_file"
    fi

    if [[ -n "$user" ]]; then
        echo "User=$user" >> "$service_file"
    fi

    if [[ -n "$group" ]]; then
        echo "Group=$group" >> "$service_file"
    fi

    if [[ -n "$environment" ]]; then
        # Split environment string and add each as a separate Environment line
        IFS=' ' read -ra ENV_ARRAY <<< "$environment"
        for env_var in "${ENV_ARRAY[@]}"; do
            echo "Environment=$env_var" >> "$service_file"
        done
    fi

    if [[ -n "$exec_start_pre" ]]; then
        echo "ExecStartPre=$exec_start_pre" >> "$service_file"
    fi

    if [[ -n "$exec_stop" ]]; then
        echo "ExecStop=$exec_stop" >> "$service_file"
    fi

    # Add the [Install] section
    cat >> "$service_file" << EOF

[Install]
WantedBy=$wanted_by
EOF
    return 0
}
