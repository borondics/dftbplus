!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2006 - 2020  DFTB+ developers group                                               !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

!> Contains MPI related environment settings
module dftbp_mpienv
  use dftbp_accuracy, only : lc
  use dftbp_mpifx
  use dftbp_message
  implicit none
  private

  public :: TMpiEnv, TMpiEnv_init


  !> Contains MPI related environment settings
  type :: TMpiEnv

    !> Global MPI communicator
    type(mpifx_comm) :: globalComm

    !> Communicator to access processes within current group
    type(mpifx_comm) :: groupComm

    !> Communicator to access equivalent processes in other groups
    type(mpifx_comm) :: interGroupComm

    !> Size of the process groups
    integer :: groupSize

    !> Number of processor groups
    integer :: nGroup

    !> Group index of the current process (starts with 0)
    integer :: myGroup

    !> Global rank of the processes in the given group
    integer, allocatable :: groupMembers(:)

    !> Whether current process is the global master
    logical :: tGlobalMaster

    !> Whether current process is the group master
    logical :: tGroupMaster

  end type TMpiEnv


contains

  !> Initializes MPI environment.
  ! ---------------------------------------------------------------
  ! Initializes global communicator and group communicators
  ! Example:
  ! globalSize = 10
  ! nGroup = 2
  ! groupSize = 5 
  !                        rank
  ! globalComm:      0 1 2 3 4 5 6 7 8 9
  ! groupComm:       0 1 2 3 4 0 1 2 3 4
  ! interGroupComm:  0 0 0 0 0 1 1 1 1 1
  ! ---------------------------------------------------------------
  ! SCALAPACK
  ! Different groups handle different kpoints/spin (iKS)
  ! All procs within a group know eigenval(:,iKS)
  ! These are distributed to all other nodes using interGroupComm
  ! eigenvec(:,:,iKS) are used to build the density matrix, DM(:,:,iKS)
  ! DM(:,:,iKS) contains kWeight(iK) and occupation(iKS)
  ! total DM(:,:) is obtained by mpiallreduce with MPI_SUM 
  ! ---------------------------------------------------------------
  ! LIBNEGF
  ! Different groups handle different kpoints/spin (iKS)
  ! All procs within a group know densMat(:,:,iKS)
  ! DM(:,:,iKS) contains kWeight(iK) and occupation(iKS)
  ! total DM(:,:) is obtained by mpiallreduce with MPI_SUM 
  ! ---------------------------------------------------------------
  subroutine TMpiEnv_init(this, nGroup)

    !> Initialised instance on exit
    type(TMpiEnv), intent(out) :: this

    !> Number of process groups to create
    integer, intent(in) :: nGroup

    character(lc) :: tmpStr
    integer :: myRank, myGroup

    call this%globalComm%init()
    this%nGroup = nGroup
    this%groupSize = this%globalComm%size / this%nGroup
    if (this%nGroup * this%groupSize /= this%globalComm%size) then
      write(tmpStr, "(A,I0,A,I0,A)") "Number of groups (", this%nGroup,&
          & ") not compatible with number of processes (", this%globalComm%size, ")"
      call error(tmpStr)
    end if

    this%myGroup = this%globalComm%rank / this%groupSize
    myRank = mod(this%globalComm%rank, this%groupSize)
    call this%globalComm%split(this%myGroup, myRank, this%groupComm)
    allocate(this%groupMembers(this%groupSize))
    call mpifx_allgather(this%groupComm, this%globalComm%rank, this%groupMembers)

    myGroup = myRank
    myRank = this%myGroup
    call this%globalComm%split(myGroup, myRank, this%interGroupComm)

    this%tGlobalMaster = this%globalComm%master
    this%tGroupMaster = this%groupComm%master

    if (this%tGlobalMaster .and. .not. this%tGroupMaster) then
      call error("Internal error: Global master process is not a group master process")
    end if

  end subroutine TMpiEnv_init


end module dftbp_mpienv
