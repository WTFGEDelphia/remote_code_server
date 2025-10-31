# VS Code Remote SSH on Docker

This project provides a comprehensive solution for setting up a VS Code development environment within a Docker container, accessible via the Remote-SSH extension. It offers both online and offline setup methods to cater to different network conditions.

## Features

-   **Dockerized Development**: Encapsulate your development environment in a portable and reproducible Docker container.
-   **Seamless VS Code Integration**: Use your local VS Code instance to develop inside the container, providing a native and rich user experience.
-   **Online Mode**: Builds the Docker image by downloading the VS Code Server on the fly. Ideal for environments with stable internet access.
-   **Offline Mode**: Builds the Docker image by embedding a pre-downloaded VS Code Server, making it perfect for air-gapped or restricted networks.
-   **Simplified Management**: Uses Docker Compose for easy management of the container's lifecycle, ports, and volumes.
-   **Customizable**: The provided Dockerfiles can be easily modified to include additional tools and dependencies for your specific projects.

## 1. Prerequisites

Before you begin, ensure you have the following installed on your local machine:

-   **Docker**: The containerization platform to build and run the images.
-   **Docker Compose**: The tool for defining and running multi-container Docker applications.
-   **Visual Studio Code**: Your local code editor.
-   **Remote - SSH Extension for VS Code**: This is the core component that enables the remote development capability. You can install it directly from the VS Code Marketplace.
    1.  Open VS Code.
    2.  Go to the Extensions view (`Ctrl+Shift+X`).
    3.  Search for `Remote - SSH`.
    4.  Click "Install".
-   **OpenSSH Client**: Most operating systems (Linux, macOS, Windows 10/11) have this pre-installed.

## 2. How to Use

### Step 1: Build the Docker Image

You can choose to build an "online" or "offline" image based on your needs.

-   **Online Build**: This version downloads the VS Code server during the image build process.
    ```bash
    docker build -f code_online.Dockerfile -t remote_code_server:online .
    ```

-   **Offline Build**: This version uses a pre-downloaded VS Code server. The `Dockerfile` and `code_offline.Dockerfile` are configured for this.
    ```bash
    docker build -f code_offline.Dockerfile -t remote_code_server:offline .
    ```

### Step 2: Run the Container

Use the corresponding Docker Compose file to start the container in the background.

-   **Run Online Container**:
    ```bash
    docker-compose -f code_online.docker-compose.yml up -d
    ```

-   **Run Offline Container**:
    ```bash
    docker-compose -f code_offline.docker-compose.yml up -d
    ```

This will start a container named `container_code_online` or `container_code_offline` and map port `2222` on your local machine to port `22` inside the container.

### Step 3: Configure SSH Connection

To allow VS Code to connect smoothly, you need to add an entry to your local SSH configuration file.

1.  Open your SSH config file, typically located at `~/.ssh/config` on Linux/macOS or `C:\Users\<YourUser>\.ssh\config` on Windows.
2.  Add the following block:

    ```ssh-config
    Host vscode-docker-dev
        HostName localhost
        User root
        Port 2222
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
    ```

    -   **Host**: A nickname for your connection (e.g., `vscode-docker-dev`).
    -   **HostName**: `localhost` since the port is mapped to your local machine.
    -   **User**: The user inside the container. The provided Dockerfiles set up `root` and `vscode` users with the password `password`. For initial setup, `root` is straightforward.
    -   **Port**: The host port you mapped in the `docker-compose.yml` file (`2222`).
    -   `StrictHostKeyChecking` and `UserKnownHostsFile` are added for convenience to prevent host key errors when the container is rebuilt.

### Step 4: Connect with VS Code

1.  Open VS Code.
2.  Click the green Remote Window button in the bottom-left corner of the window.
3.  Select **"Connect to Host..."** from the dropdown menu.
4.  Choose the host you configured in the previous step (e.g., `vscode-docker-dev`).
5.  A new VS Code window will open. It will ask for the password. Enter `password`.
6.  You are now connected! The new window is running against the Docker container. You can open folders, use the integrated terminal, and install extensions directly into the containerized environment.

## Security Best Practices

The default configuration is designed for ease of use and testing. For a more secure or production-like environment, consider the following improvements:

-   **Use SSH Keys**: Modify the `Dockerfile` and `docker-compose.yml` to use SSH key-based authentication instead of passwords. You can do this by mounting your `~/.ssh/authorized_keys` file into the container.
-   **Avoid Root User**: Create a non-root user in the `Dockerfile` with `sudo` privileges if needed, and use that user for your SSH connection. The provided `code_offline.Dockerfile` already creates a `vscode` user.
-   **Limit Port Exposure**: If possible, do not expose the SSH port to the public internet. Keep it bound to `127.0.0.1` if you are only accessing it locally.