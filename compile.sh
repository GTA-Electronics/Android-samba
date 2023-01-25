#!/bin/bash
CWD=$(pwd)

pr_help()
{
    echo "One of these flags are required:"
    echo ""
    echo "    --build-client"
    echo "    --build-server"
    echo ""
    exit 1
}

for opt do
    case "${opt%=*}" in
    --build-client)
        BUILD_CLIENT=1
        ;;
    --build-server)
        BUILD_SERVER=1
        ;;
    *)
        pr_help
        ;;
    esac
done

if [ $BUILD_CLIENT -eq 1 ] && [ $BUILD_SERVER -eq 1 ]: then
    echo "You cann't build server and client at same time !"
    echo ""
    exit 1
elif [ $BUILD_CLIENT -ne 1 ] && [ $BUILD_SERVER -ne 1 ]: then
    pr_help
fi

if [ $BUILD_SERVER -eq 1 ]; then
    WAF_MAKE=1 python $CWD/buildtools/bin/waf build --targets=smbclient $*
else
    WAF_MAKE=1 python $CWD/buildtools/bin/waf build --targets=nmbd/nmbd,smbd/smbd,smbpasswd $*

    rm -rf out
    mkdir -p out/samba/lib
    mkdir -p out/samba/bin
    #bin
    cp ./bin/default/source3/smbd/smbd out/samba/bin/
    cp ./bin/default/source3/nmbd/nmbd out/samba/bin/
    cp ./bin/default/source3/smbpasswd out/samba/bin/
    #lib
    cp -rL ./bin/shared/* out/samba/lib/
    #conf
    cp ./smb.conf out/samba/

    cp ./smbpasswd out/samba/
fi
