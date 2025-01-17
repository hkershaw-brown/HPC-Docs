!!! note
    This page is intended for users who need to fetch container images from an external repository, and/or build a container for a specific use case.  If you simply want to run a container that has been shared with you through a GLADE file system path see [Running Containers](./running_containers.md).


## Introduction
The first step in running a container is usually (i) to "pull" a pre-existing container from an external repository, or (ii) to build a container according to a recipe. When a container is built locally, it is usually desirable to then share it with a larger community, often by "pushing" the resulting image to an external repository.  We cover these topics generally in the next section, which will be valuable both for users unfamiliar with containers and to others familiar with a tool such as Docker but unclear on how to execute these steps specifically in one of our supported runtimes.

Additionally, we provide special support infrastructure for users wishing to create a container that mimics the NCAR environment and document these processes [later in this page](#building-a-container-specifically-to-mimic-the-ncar-user-environment).

---

## General container workflows

The concepts of pull, build, and push are common regardless of container run-time, however the specifics vary. We will highlight these specific steps for each supported run time in the examples below.

!!! info "Example scenario"
    In the examples below we will work incrementally through a simple but realistic example use case: building a container using the latest version of a different operating system to provide tools not available on the host.  Specifically, we will:

    1. Begin with a basic [Rocky Linux 9 container image](https://hub.docker.com/_/rockylinux) fetched from Docker Hub,

    2. Demonstrate building our own derived container image with additional packages and tools, and

    3. Demonstrate sharing the resulting image.

### Pulling a container

!!! example "Pulling & converting a simple container image"
    === "Apptainer"
        **Pulling & listing images**

        We will use the command `singularity pull` from the `apptainer` module to pull our image and save it in Singularity Image Format (SIF):
        ```console title="singularity pull"
        casper$ singularity pull ./rocky9.sif docker://rockylinux/rockylinux:9
        INFO:    Converting OCI blobs to SIF format
        INFO:    Starting build...
        Getting image source signatures
        Copying blob 4031b0359885 done
        Copying config 175264fac6 done
        Writing manifest to image destination
        Storing signatures
        2023/11/27 15:12:32  info unpack layer: sha256:4031b03598854f77c4ae1e53c2fdca86fdb41eb95f1f051416ce2e363fc8cdd2
        INFO:    Creating SIF file...
        ```
        !!! info inline end "Prefer Apptainer's SIF image format"
            SIF images are much better suited for use on large parallel file systems than large directory trees, and can easily be shared with other users.

        Like most run times, Apptainer supports several image storage formats, including unpacked directory tree "sandboxes" and compressed read-only image bundles in Singularity Image Format (SIF). We recommend using read-only, compressed SIF images for both performance and best practices reasons. While sandboxes may be tempting to create "writable" containers, they create sprawling directory trees of many small files, which slow container startup time and complicate management especially on shared, parallel file systems.   Furthermore, writable container images undercut the encapsulation and repeatability benefits offered by containerization.  It is possible to run containers on top of SIF images with *temporary* write layers if necessary.

        **Running a simple command from the container**

        We cover running containers in much more detail [here](./running_containers.md), however below we will use the command `ch-run` to inspect the contents of the file `/etc/os-release` *inside the container*:
        ```console title="singularity exec"
        casper$ singularity exec ./rocky9.sif cat /etc/os-release
        NAME="Rocky Linux"
        VERSION="9.2 (Blue Onyx)"
        ID="rocky"
        ID_LIKE="rhel centos fedora"
        VERSION_ID="9.2"
        PLATFORM_ID="platform:el9"
        PRETTY_NAME="Rocky Linux 9.2 (Blue Onyx)"
        ANSI_COLOR="0;32"
        LOGO="fedora-logo-icon"
        CPE_NAME="cpe:/o:rocky:rocky:9::baseos"
        HOME_URL="https://rockylinux.org/"
        BUG_REPORT_URL="https://bugs.rockylinux.org/"
        SUPPORT_END="2032-05-31"
        ROCKY_SUPPORT_PRODUCT="Rocky-Linux-9"
        ROCKY_SUPPORT_PRODUCT_VERSION="9.2"
        REDHAT_SUPPORT_PRODUCT="Rocky Linux"
        REDHAT_SUPPORT_PRODUCT_VERSION="9.2"
        ```
        This is functionally a `hello-world` type demonstration, and can be compared to the same file on the host to show we are indeed running in a different environment.

        ---

        !!! note "`apptainer` vs. `singularity`"
            As of version 3, the commands `apptainer` and `singularity` are synonymous.  We will use the latter as there is a wide array of existing documentation referencing the `singularity` executable across the internet.

    === "Charliecloud"
        **Pulling & listing images**

        We will use the command `ch-image` from the `charliecloud` module to pull and list images:
        ```console title="ch-image pull & ch-image list"
        # Pull the requested image, storing into Charliecloud's internal format
        casper$ ch-image pull rockylinux/rockylinux:9
        pulling image:    rockylinux/rockylinux:9
        requesting arch:  amd64
        manifest list: downloading: 100%
        manifest: downloading: 100%
        config: downloading: 100%
        layer 1/1: 4031b03: downloading: 63.6/63.6 MiB (100%)
        pulled image: adding to build cache
        flattening image
        layer 1/1: 4031b03: listing
        validating tarball members
        layer 1/1: 4031b03: changed 34 absolute symbolic and/or hard links to relative
        resolving whiteouts
        layer 1/1: 4031b03: extracting
        image arch: amd64

        # List all known images
        casper$ ch-image list
        rockylinux/rockylinux:9
        ```
        See `ch-image --help` for more details and options.

        !!! info inline end "Prefer Charliecloud's bundled SquashFUSE image format"
            After running the two commands above, the requested container has been downloaded and unpacked into Charliecloud's [storage directory tree](https://hpc.github.io/charliecloud/ch-image.html?highlight=storage%20directory#storage-directory) in its native format.  This often is on temporary storage, and it is advisable to use `ch-convert` to convert the image to one of several other [image formats](https://hpc.github.io/charliecloud/ch-convert.html#image-formats) before use.

        **Converting the image**

        On NCAR's HPC systems we strive to support the `squash` SquashFS file system archive, which allows the container to be converted to a single, compressed file.  This is much better suited for use on large parallel file systems, and can easily be shared with other users.  The command `ch-convert` can be used to convert images between Charliecloud's [supported formats](https://hpc.github.io/charliecloud/ch-convert.html#image-formats).

        ```console title="ch-convert"
        # Convert from Charliecloud's internal format to a compressed SquashFUSE image
        casper$ ch-convert rockylinux/rockylinux:9 ./rocky9.sqfs
        Parallel mksquashfs: Using 72 processors
        Creating 4.0 filesystem on ./rocky9.sqfs, block size 65536.
        [=====================================================================|] 8075/8075 100%

        Exportable Squashfs 4.0 filesystem, gzip compressed, data block size 65536
                compressed data, compressed metadata, compressed fragments,
                compressed xattrs, compressed ids
                duplicates are removed
        Filesystem size 61709.90 Kbytes (60.26 Mbytes)
                35.85% of uncompressed filesystem size (172122.07 Kbytes)
        Inode table size 80336 bytes (78.45 Kbytes)
                27.36% of uncompressed inode table size (293634 bytes)
        Directory table size 88626 bytes (86.55 Kbytes)
                43.45% of uncompressed directory table size (203971 bytes)
        Number of duplicate files found 1875
        Number of inodes 8122
        Number of files 6194
        Number of fragments 693
        Number of symbolic links 909
        Number of device nodes 0
        Number of fifo nodes 0
        Number of socket nodes 0
        Number of directories 1019
        Number of hard-links 0
        Number of ids (unique uids + gids) 1
        Number of uids 1
                root (0)
        Number of gids 1
                root (0)
        ```
        See `ch-convert --help` for more details and options.

        **Running a simple command from the container**

        We cover running containers in much more detail [here](./running_containers.md), however below we will use the command `ch-run` to inspect the contents of the file `/etc/os-release` *inside the container*:
        ```console title="ch-run"
        casper$ ch-run ./rocky9.sqfs -- cat /etc/os-release
        NAME="Rocky Linux"
        VERSION="9.2 (Blue Onyx)"
        ID="rocky"
        ID_LIKE="rhel centos fedora"
        VERSION_ID="9.2"
        PLATFORM_ID="platform:el9"
        PRETTY_NAME="Rocky Linux 9.2 (Blue Onyx)"
        ANSI_COLOR="0;32"
        LOGO="fedora-logo-icon"
        CPE_NAME="cpe:/o:rocky:rocky:9::baseos"
        HOME_URL="https://rockylinux.org/"
        BUG_REPORT_URL="https://bugs.rockylinux.org/"
        SUPPORT_END="2032-05-31"
        ROCKY_SUPPORT_PRODUCT="Rocky-Linux-9"
        ROCKY_SUPPORT_PRODUCT_VERSION="9.2"
        REDHAT_SUPPORT_PRODUCT="Rocky Linux"
        REDHAT_SUPPORT_PRODUCT_VERSION="9.2"
        ```
        This is functionally a `hello-world` type demonstration, and can be compared to the same file on the host to show we are indeed running in a different environment.

    === "Podman"
        **Pulling & listing images**

        We will use the command `podman pull` and `podman images` from the `podman` module to pull and list images:
        ```console title="podman image pull & podman images"
        # Pull the requested image, storing into Podman's internal image format
        casper$ podman image pull docker://rockylinux/rockylinux:9
        Trying to pull docker.io/rockylinux/rockylinux:9...
        Getting image source signatures
        Copying blob 4031b0359885 done
        Copying config 175264fac6 done
        Writing manifest to image destination
        Storing signatures
        175264fac6da4392fb2a9761583c81f509745629daee81de29beb7051f360db7

        # list known (downloaded) images
        casper$ podman images
        REPOSITORY                       TAG         IMAGE ID      CREATED       SIZE
        docker.io/rockylinux/rockylinux  9           175264fac6da  6 months ago  181 MB
        ```


        **Running a simple command from the container**

        We cover running containers in much more detail [here](./running_containers.md), however below we will use the command `ch-run` to inspect the contents of the file `/etc/os-release` *inside the container*:
        ```console title="podman run"
        casper$  podman run rockylinux/rockylinux:9 cat /etc/os-release
        NAME="Rocky Linux"
        VERSION="9.2 (Blue Onyx)"
        ID="rocky"
        ID_LIKE="rhel centos fedora"
        VERSION_ID="9.2"
        PLATFORM_ID="platform:el9"
        PRETTY_NAME="Rocky Linux 9.2 (Blue Onyx)"
        ANSI_COLOR="0;32"
        LOGO="fedora-logo-icon"
        CPE_NAME="cpe:/o:rocky:rocky:9::baseos"
        HOME_URL="https://rockylinux.org/"
        BUG_REPORT_URL="https://bugs.rockylinux.org/"
        SUPPORT_END="2032-05-31"
        ROCKY_SUPPORT_PRODUCT="Rocky-Linux-9"
        ROCKY_SUPPORT_PRODUCT_VERSION="9.2"
        REDHAT_SUPPORT_PRODUCT="Rocky Linux"
        REDHAT_SUPPORT_PRODUCT_VERSION="9.2"
        ```
        This is functionally a `hello-world` type demonstration, and can be compared to the same file on the host to show we are indeed running in a different environment.

        ---

        !!! note "Podman vs. Docker"
            Podman [seeks to be functionally equivalent with Docker](https://docs.podman.io/en/latest/), so many Docker commands you may be familiar with will work the same.




### Building a container from a definition file
In the examples above, we pulled a ready-made container image.  For most practical applications we will want instead to build our own container image, often beginning with a base image from a public repository as shown above but extending it to meet a specific need.  This process begins with a "recipe" file listing the steps required.  By way of terminology, such recipes are typically referred to as `Dockerfiles` and usually follow a common format.  Charliecloud and Podman support `Dockerfiles` directly.  Apptainer is an outlier in this regard, and supports its own "definition" file format (commonly referred to as `def`-files).  In this section we describe the general form of these build recipe files and provide simple build examples for the supported run-times.

#### Anatomy of build recipes

**`Dockerfiles` and Apptainer `Definition` files**

=== "`Dockerfile`"
    Following from the [Docker documentation](https://docs.docker.com/engine/reference/builder/#dockerfile-reference), a basic `Dockerfile` is
    ```pre title="Sample Dockerfile"
    FROM rockylinux/rockylinux:9

    RUN yum -y install dnf-plugins-core \
        && dnf -y update \
        && dnf config-manager --set-enabled crb \
        && dnf -y install epel-release \
        && dnf -y groupinstall "Development Tools" \
        && dnf -y install \
               chrpath \
               bzip2 autoconf automake libtool \
               gcc gcc-c++ gcc-gfortran emacs make procps-ng openmpi-devel \
        && yum clean all

    RUN
       [...]

    ENV
       [...]
    ```
=== "Apptainer `Definition` files"
    Following from the [Apptainer documentation](https://apptainer.org/docs/user/main/definition_files.html), a basic definition file is
    ```pre title="Sample Definition File"
    Bootstrap: docker
    From: docker.io/rockylinux/rockylinux:9

    %post
        yum -y install dnf-plugins-core \
            && dnf -y update \
            && dnf config-manager --set-enabled crb \
            && dnf -y install epel-release \
            && dnf -y install gimp \
            && dnf clean all --verbose

    %environment
        [...]
    ```

We can now use the general form of these definition files to demonstrate constructing our own derived container image.


!!! example "Building a container from a recipe file"
    === "Apptainer"
        ```pre title="Deffile:"
        ---8<--- "https://raw.githubusercontent.com/NCAR/hpc-demos/main/containers/tutorial/apptainer/Deffile"
        ```
        We use the command `singularity build` to create a compressed SIF directly from the `Deffile`:
        ```pre
        casper$ TMPDIR=/var/tmp/ singularity build my_rocky9.sif Deffile
        [...]
        ```

    === "Charliecloud"
        ```pre title="Dockerfile:"
        ---8<--- "https://raw.githubusercontent.com/NCAR/hpc-demos/main/containers/tutorial/charliecloud/Dockerfile"
        ```
        We use the command `ch-image build` to build a container from the `Dockerfile`:
        ```pre
        casper$ ch-image build --force fakeroot --tag my_rocky9 .
        [...]
        ```
        Charliecloud builds in its internal format, which requires conversion before running.  As shown above, we will convert the image to our preferred SquashFS format:
        ```pre
        casper$ ch-image list
        my_rocky9
        rockylinux/rockylinux:9

        benkirk@casper20(61)$ ch-convert my_rocky9 ./my_rocky9.sqfs
        input:   ch-image  my_rocky9
        output:  squash    ./my_rocky9.sqfs
        packing ...
        [...]
        ```

    === "Podman"
        ```pre title="Dockerfile:"
        ---8<--- "https://raw.githubusercontent.com/NCAR/hpc-demos/main/containers/tutorial/podman/Dockerfile"
        ```
        We use the command `podman build` to build a container from the `Dockerfile`:
        ```pre
        casper$ podman build --tag my_rocky9 .
        [...]
        ```

!!! warning "Container image builds directly on the HPC systems can be fragile"
    As discussed previously, security concerns in the HPC environment restrict certain container image build operations that require elevated privileges.  Simple operations such as compiling code within a container to augment with a tool, or customizing the execution environment will likely work fine.  Additionally, installing most packages through an operating system package manager usually works as well.

    A common failure, however, is building containers that switch user IDs or change ownership of files within the build process.  This can occur explicitly through a `USER` statement or through installation of some package.  In either case, the underlying issue is that on the host the user has access to only a single user ID  - their own.  Many complex containers violate this restriction.  We cannot support such build processes securely, even with so-called "rootless" container installations.

    An alternative and popular workflow is to build containers *externally* to the HPC environment on a resource where the user has elevated privileges, likely using Docker.  The finalized images is then pushed to an image repository, and then pulled into the HPC environment.  We will not demonstrate the approach here due to the variability of external environments, however the process is straightforward for the user familiar with the build steps discussed below.


### Pushing a container

<!---
The final step in the overall container image build process is often "pushing" the container to one of several registries, allowing it to be shared with others and retrieved again in the future.  Several popular container registry examples are [Docker Hub](https://hub.docker.com/), [Quay.io](https://quay.io/) and [GitHub's container registry](https://github.blog/2021-06-21-github-packages-container-registry-generally-available/).  In the examples below we will focus on Docker Hub, however the general process is easily transferable to other registries based on the [Open Container Initiative](https://opencontainers.org/faq/) standards.
--->

!!! danger "Under Development"
    The best practices for sharing container images is currently under development.  The availability and pricing models of external repositories is frequently changing, complicating a general recommendation.

    ---

    **NCAR does not currently offer a custom centralized image repository for HPC user access.**

    For sharing on the HPC systems, we currently recommend revision-controlled build processes and sharing resulting compressed imaged files directly.  Alternatively, a popular model for *external* container building is to push the resulting images to Docker Hub, where they can be pulled into the HPC environment using the techniques outlined above.


---

<!-- ## Building a container specifically to mimic the NCAR user environment
-->

<!--  LocalWords:  Charliecloud's SquashFUSE casper Charliecloud Apptainer SIF -->
