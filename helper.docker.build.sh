#args="${@//--env/--build-arg}"
name=$(cat helper.docker.name.txt)
args=""
echo "docker build $args -t $name ."
docker build $args -t $name .
