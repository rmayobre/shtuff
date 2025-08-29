#!/usr/bin/env bash

# Usage: service [OPTIONS]
#
# Create a systemd service file with the specified configuration.
#
# OPTIONS:
#     -n, --name NAME                 Service name (required)
#     -d, --description DESC          Service description (required)
#     -e, --exec-start COMMAND        Command to start the service (required)
#     -w, --working-directory DIR     Working directory for the service
#     -u, --user USER                 User to run the service as
#     -g, --group GROUP               Group to run the service as
#     -r, --restart POLICY            Restart policy (default: on-failure)
#     --restart-sec SECONDS           Restart delay in seconds (default: 5)
#     --wanted-by TARGET              Target for WantedBy (default: multi-user.target)
#     --environment ENV               Environment variables (format: "VAR1=value1 VAR2=value2")
#     --exec-start-pre COMMAND        Command to run before starting the service
#     --exec-stop COMMAND             Command to run when stopping the service
#     -o, --output-dir DIR            Output directory (default: /etc/systemd/system)
#
# EXAMPLES:
#
#     service \
#         --name "myapp" \
#         --description "My Web Application" \
#         --exec-start "/usr/bin/node /opt/myapp/server.js" \
#         --user "www-data" \
#         --working-directory "/opt/myapp"
#
#     service \
#         --name "api-server" \
#         --description "API Server" \
#         --exec-start "/usr/local/bin/api-server" \
#         --user "apiuser" \
#         --environment "PORT=8080 NODE_ENV=production" \
#         --restart "always"
#
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
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$service_name" ]]; then
        echo "Error: Service name is required (use -n or --name)" >&2
        return 1
    fi

    if [[ -z "$description" ]]; then
        echo "Error: Service description is required (use -d or --description)" >&2
        return 1
    fi

    if [[ -z "$exec_start" ]]; then
        echo "Error: ExecStart command is required (use -e or --exec-start)" >&2
        return 1
    fi

    # Ensure service name ends with .service
    if [[ "$service_name" != *.service ]]; then
        service_name="${service_name}.service"
    fi

    local service_file="${output_dir}/${service_name}"

    echo "Creating service file: $service_file"

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

    echo "Service file created successfully!"
    echo "To enable and start the service, run:"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable $service_name"
    echo "  sudo systemctl start $service_name"
    echo ""
    echo "To check service status:"
    echo "  sudo systemctl status $service_name"

    return 0
}
