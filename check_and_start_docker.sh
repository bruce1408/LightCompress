#!/bin/bash

# 判断是否在 Docker 环境中
if [ -f /.dockerenv ]; then
    echo "错误: 当前已经在 Docker 容器内，不能创建新容器。"
    exit 1
fi

usage() {
    echo "Usage: $0 [container_name]"
    echo "如果不提供 container_name，将会提示输入。"
    exit 1
}

# 获取容器名称
if [ $# -ge 1 ]; then
    CONTAINER_NAME="$1"
else
    read -r -p "请输入 Docker 容器名称: " CONTAINER_NAME
    if [ -z "$CONTAINER_NAME" ]; then
        echo "错误: 未提供容器名称。"
        usage
    fi
fi

CONDA_ENV="/home/bruce_ultra/.conda/envs/torch113_cuda116"  # aimet conda 环境路径
WORKSPACE="/home/bruce_ultra/workspace/quant_workspace/Quantizer-Tools"  # 替换为你的工作目录路径

# Conda 初始化脚本路径
CONDA_INIT="/home/bruce_ultra/miniconda3/etc/profile.d/conda.sh"

# 检查容器是否存在
if [[ $(docker ps -a --filter "name=^/${CONTAINER_NAME}$" --format "{{.Names}}") == "$CONTAINER_NAME" ]]; then
    # 容器存在
    # 检查容器是否在运行
    if [[ $(docker ps --filter "name=^/${CONTAINER_NAME}$" --filter "status=running" -q) ]]; then
        echo "容器 '$CONTAINER_NAME' 已经启动，直接进入容器并使用 zsh 并激活 Conda 环境..."
    else
        echo "容器 '$CONTAINER_NAME' 存在但未启动，启动容器..."
        docker start "${CONTAINER_NAME}"
    fi
    # 进入容器并激活 Conda 环境
    # docker exec -it $CONTAINER_NAME 
    docker exec -it "${CONTAINER_NAME}" /bin/zsh
    # docker exec -it $CONTAINER_NAME cat /etc/passwd | grep $(whoami)
    # docker exec -it $CONTAINER_NAME which zsh

    # 这里不加-c命令切换了，而是直接在docker的zsh中进行配置
else
    echo "容器 '$CONTAINER_NAME' 不存在，创建并启动容器并进入..."
    
    # 这里 -u 还是改回和主机一样的id，这样的话，就可以对文件进行git 修改，但是缺乏root权限，所以需要安装依赖库的话就
    # 需要重新用root权限打开文件     docker exec -u root -it $CONTAINER_NAME /bin/bash
    docker run --name "${CONTAINER_NAME}" -it -u "$(id -u):$(id -g)" \
        -v /etc/passwd:/etc/passwd:ro \
        -v /etc/group:/etc/group:ro \
        -v /etc/localtime:/etc/localtime:ro \
        -v "${HOME}:${HOME}" \
        -v /opt/qcom:/opt/qcom \
        -v "${WORKSPACE}:${WORKSPACE}" \
        -v "/home/bruce_ultra/Documents":"/home/bruce_ultra/Documents" \
        -v "/home/bruce_ultra/Downloads":"/home/bruce_ultra/Downloads" \
        -v "/home/bruce_ultra/data":"/home/bruce_ultra/data" \
        -v "/home/bruce_ultra/workspace/onnx_models":"/home/bruce_ultra/workspace/onnx_models" \
        -v "/DataVault/datasets":"/DataVault/datasets" \
        -v /usr/local/cuda-11.8:/usr/local/cuda-11.8 \
        --gpus all \
        --restart always \
        --shm-size=16G \
        --entrypoint /bin/bash \
        -w "${WORKSPACE}" \
        --hostname docker_env aimet_1304 \
        -c "source $CONDA_INIT && conda activate $CONDA_ENV && exec bash"
    echo -e "\"
        sudo docker exec -it -u root infer_env /bin/bash\n\
        \n\
        容器已经创建完成，请先安装zsh，然后把主机 zsh 和 p10.zsh 配置文件拷贝到docker容器下的 /root 目录即可，\n\
        并在 zsh 脚本添加 conda 环境路径，然后使用这个脚本重启容器"
fi