#!/bin/bash
#

#
# iphone and simulator sdks
#
IPHONE_SIM_SDK_LIST=(iphonesimulator10.0 iphonesimulator9.3 iphonesimulator9.2 iphonesimulator9.1 iphonesimulator9.0 iphonesimulator8.4 iphonesimulator8.3 iphonesimulator8.1 iphonesimulator8.0 iphonesimulator7.1 iphonesimulator7.0 iphonesimulator6.1 iphonesimulator6.0 iphonesimulator5.1 iphonesimulator5.0 iphonesimulator4.3 iphonesimulator4.2 iphonesimulator4.1 iphonesimulator4.0)
IPHONE_DEV_SDK_LIST=(iphoneos10.0 iphoneos9.3 iphoneos9.2 iphoneos9.1 iphoneos9.0 iphoneos8.4 iphoneos8.3 iphoneos8.1 iphoneos8.0 iphoneos7.1 iphoneos7.0 iphoneos6.1 iphoneos6.0 iphoneos5.1 iphoneos5.0 iphoneos4.3 iphoneos4.2 iphoneos4.1 iphoneos4.0)

XCODEBUILD=xcodebuild

#
# project configuration
#
PROJECT_NAME=ILiveSDK
PROJBASE="$(cd `dirname $0`; pwd)"
BUILD_DIR=build
HEADERDIR=ILiveSDK/include
RESULT_DIR=result



#
#
FRAMEWORK_NAME=${PROJECT_NAME}

#
# error code
#
returnCode=0

#
# build styles (Release, Debug)
#
#SDK_BUILD_STYLE_LIST=(Debug)
#SDK_BUILD_STYLE_LIST=(Release)
SDK_BUILD_STYLE_LIST=(Release)

DIST_DIR_NAME_LIST=(ILiveSDK_Release)

BUILD_ARCH_LIST_OS=(armv7 arm64)
BUILD_ARCH_LIST_SIM=(i386 x86_64)

#
# prepare build directories
#
prepareDirs()
{
	/bin/echo Preparing directory structures

	# /bin/rm -Rf $PROJBASE/$BUILD_DIR
    # /bin/rm -Rf $PROJBASE/$RESULT_DIR
	# /bin/mkdir $BUILD_DIR
	# /bin/mkdir $HEADERDIR
    # /bin/mkdir $RESULT_DIR

    rm -rf ${PROJBASE}/${BUILD_DIR}
	rm -rf ${PROJBASE}/temp
}

#
# choose an sdk
#
chooseSDKs()
{
    # show xcodebuild verison
    ${XCODEBUILD} -version
	
	# choose simulator sdk
	for SDK in ${IPHONE_SIM_SDK_LIST[*]}
	do
	    echo $SDK
		${XCODEBUILD} -showsdks | grep -q $SDK
		if [ $? = 0 ]
		then
		    SIMULATOR_SDK=$SDK
			break
		fi
	done
	
	# choose device sdk
	for SDK in ${IPHONE_DEV_SDK_LIST[*]}
	do
	    echo $SDK
		${XCODEBUILD} -showsdks | grep -q $SDK
		if [ $? = 0 ]
		then
		    IPHONE_SDK=$SDK
			break
		fi
	done
	
	echo "SDK choosen: $SIMULATOR_SDK and $IPHONE_SDK"
}


writeVersion()
{
	buildVersion=`git rev-list --all|wc -l`
	# buildVersion=${ILiveSDK_version%%:*}
	# buildVersion=${buildVersion%%M*}



	echo "ILiveSDK Version:" $buildVersion

	echo "#ifndef ILiveSDK_VERSION_H" > ILiveSDK/include/ILiveSDKVersion.h
	echo "#define ILiveSDK_VERSION_H" >> ILiveSDK/include/ILiveSDKVersion.h

	echo "#define ILiveSDK_VERSION $buildVersion">> ILiveSDK/include/ILiveSDKVersion.h

	echo "#endif" >> ILiveSDK/include/ILiveSDKVersion.h
}


buildCommand()
{
	PROJ_PATH=$1
	TARGET=$2
	BUILD_TYPE=$3
	SDK=$4

	${XCODEBUILD} -project $PROJ_PATH -target $TARGET -configuration $BUILD_TYPE -sdk $SDK
	ret=$?
	if ! [ $ret = 0 ] ;then
		echo "Error, ${XCODEBUILD} returns $ret building device version of $PROJ_PATH->$TARGET->$BUILD_STYLE->$SDK"
		returnCode=$(($returnCode + $ret))
		exit 100
	fi
}

buildAllPlatform()
{
	PROJ_PATH=$1
	TARGET=$2

	buildCommand $PROJ_PATH $TARGET $SDK_BUILD_STYLE $IPHONE_SDK
	buildCommand $PROJ_PATH $TARGET $SDK_BUILD_STYLE $SIMULATOR_SDK
}

#
# build msf sdk(device and simulator version)
#
buildILiveSDK()
{
	### ILiveSDK
	buildAllPlatform ILiveSDK.xcodeproj ILiveSDK
}

extractObjectFat()
{
	SOURCE=$1
	ARCH=$2
	TARGET_DIR=$3
	ARCHIVE=$4

	echo "Extract: $SOURCE $ARCH $TARGET"

	if [ ! -d "$TARGET" ]
	then
		mkdir -p $TARGET
	fi

	pushd $TARGET_DIR >> /dev/null

	lipo $SOURCE -thin $ARCH -output temp.a
	if [ $? -eq 0 ]
	then
		ar -x temp.a 2>>/dev/null
		rm temp.a
	else
		# ar -x $SOURCE
		echo "extractObjectFat error:$SOURCE->$ARCH"
		exit 101
	fi

	ar -q $ARCHIVE *.o 2>>/dev/null
	rm *.o

	popd >> /dev/null
}

#
# create framework
#
# name and build location
createFramework()
{
	# Clean any existing framework that might be there
	if [ -d "$FRAMEWORK_RESULT_PATH" ]
	then
		echo "Framework: Cleaning framework..."
		rm -rf "$FRAMEWORK_RESULT_PATH"
	fi
	
	# build the canonical Framework bundle directory structure
	echo "Framework: Setting up directories..."
	FRAMEWORK_DIR=$FRAMEWORK_RESULT_PATH/$FRAMEWORK_NAME.framework
	mkdir -p $FRAMEWORK_DIR
    mkdir -p $FRAMEWORK_DIR/Headers

    TEMP_DIR=$PROJBASE/temp

	# combine lib files for various platforms into one
	echo "Framework: Creating library..."

	WANT_TO_BUILD_SIMULATOR_LIBS=(
		"${PROJBASE}/$BUILD_DIR/$SDK_BUILD_STYLE-iphonesimulator/libILiveSDK.a"

	)

	WANT_TO_BUILD_OS_LIBS=(
		"${PROJBASE}/$BUILD_DIR/$SDK_BUILD_STYLE-iphoneos/libILiveSDK.a"

	)

    echo "$WANT_TO_BUILD_SIMULATOR_LIBS"
    echo "$WANT_TO_BUILD_OS_LIBS"

	CREATE_ARG_FOR_LIPO=""

	for ARCH in ${BUILD_ARCH_LIST_SIM[*]}
	do
		TARGET=$TEMP_DIR/$SDK_BUILD_STYLE/$ARCH/
		ARCHIVE=$TEMP_DIR/$SDK_BUILD_STYLE.ILiveSDK_$ARCH.a

		for LIB_LOC in ${WANT_TO_BUILD_SIMULATOR_LIBS[*]}
		do
			extractObjectFat $LIB_LOC $ARCH $TARGET $ARCHIVE
		done

		if [ $WITH_WTLOGIN_LIB == 1 ]
		then
			for LIB_LOC in ${WANT_TO_ADDITIONS_LIBS[*]}
			do
				extractObjectFat $LIB_LOC $ARCH $TARGET $ARCHIVE
			done
		fi

		CREATE_ARG_FOR_LIPO="$CREATE_ARG_FOR_LIPO $ARCHIVE"
	done

	for ARCH in ${BUILD_ARCH_LIST_OS[*]}
	do
		TARGET=$TEMP_DIR/$SDK_BUILD_STYLE/$ARCH/
		ARCHIVE=$TEMP_DIR/$SDK_BUILD_STYLE.ILiveSDK_$ARCH.a

		for LIB_LOC in ${WANT_TO_BUILD_OS_LIBS[*]}
		do
			extractObjectFat $LIB_LOC $ARCH $TARGET $ARCHIVE
		done

		if [ $WITH_WTLOGIN_LIB == 1 ]
		then
			for LIB_LOC in ${WANT_TO_ADDITIONS_LIBS[*]}
			do
				extractObjectFat $LIB_LOC $ARCH $TARGET $ARCHIVE
			done
		fi

		CREATE_ARG_FOR_LIPO="$CREATE_ARG_FOR_LIPO $ARCHIVE"
	done

	if [ $SDK_BUILD_STYLE == "Release" ]
	then
		echo "strip ..."
		strip -S $CREATE_ARG_FOR_LIPO >> /dev/null
	fi

	lipo -create $CREATE_ARG_FOR_LIPO -o "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
	echo "Framework: Copying assets into current version..."
	cp -R ${HEADERDIR}/* $FRAMEWORK_DIR/Headers/

	if [ -d "$TARGET_DIR" ]
	then
		cp -f "$FRAMEWORK_DIR/$FRAMEWORK_NAME" "$TARGET_DIR/$FRAMEWORK_NAME"
	fi
}

echo Starting...

writeVersion
prepareDirs
chooseSDKs

#
# loop through all build styles and build them all
#
i=0
for S in ${SDK_BUILD_STYLE_LIST[*]}
do
	CURRENT_STYLE=$S
	DIST_DIR_NAME=${DIST_DIR_NAME_LIST[$i]}

	echo "DIST_DIR_NAME = $DIST_DIR_NAME"
	echo "CURRENT_STYLE = $CURRENT_STYLE"

	SDK_BUILD_STYLE=$S
	FRAMEWORK_RESULT_PATH="${PROJBASE}/$BUILD_DIR/$DIST_DIR_NAME"
    echo "FRAMEWORK_RESULT_PATH = $FRAMEWORK_RESULT_PATH"


	# build sdk
	buildILiveSDK

	# create framework
	createFramework

	i=$(($i + 1))
done




#
# exit
#
/bin/echo Done.
if ! [ $returnCode = 0 ]
then
    exit 100
fi

exit 0
