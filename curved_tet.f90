module curved_tet
  use var_array
  use tetmesher
  use tet_props
  use lag_basis
  use op_cascade
  use mpi_comm_mod
  use timing
  use master_elem_distrib
  implicit none

  private

  real*8, parameter :: Radius = 2.0d0
  logical :: LOAD_BALANCE_BASED_ON_BOUNDARY = .true.


  public :: master2curved_tet
  public :: master2curved_edg_tet
  public :: curved_tetgen_geom

  ! testers
  public :: tester1

contains

  subroutine Suv(u, v, S)
    implicit none
    real*8, intent(in) :: u, v
    real*8, dimension(:), intent(out) :: S 

    S(1) = u
    S(2) = v
    S(3) = sqrt(Radius**2 - u**2 - v**2)
    ! S(3) = .5d0 - u - v

    ! done here
  end subroutine Suv

  subroutine master2curved_tet(r,s,t, uv, xA, x, y, z)
    implicit none
    real*8, intent(in) :: r, s, t
    real*8, dimension(:, :), intent(in) :: uv
    real*8, dimension(:), intent(in) :: xA
    real*8, intent(out) :: x, y, z

    ! local vars
    integer :: ii
    real*8 :: u, v, alpha
    real*8, dimension(3) :: Sf, xf
    !
    real*8 :: val   ! the value of basis  
    real*8, dimension(2) :: der, uv_fin 


    if ( abs(t - 1.0d0) <= 1.0d-15 ) then
       u = r ! simple
       v = s ! simple
    else 
       u = r/(1-t)
       v = s/(1-t)
    end if
    alpha = t

    ! compute final uv
    uv_fin = 0.0d0
    do ii = 1, 3
       call psi(etype = 1, i = ii, r = u, s = v, val = val, der = der)
       uv_fin = uv_fin + val * uv(:, ii)
    end do

    ! compute surface points
    call Suv(u = uv_fin(1), v= uv_fin(2), S = Sf)

    xf = alpha * xA + (1.0d0 - alpha) * Sf

    x = xf(1)
    y = xf(2)
    z = xf(3)

    ! done here
  end subroutine master2curved_tet

  subroutine master2curved_edg_tet(r,s,t, uv, x3, x4, x, y, z)
    implicit none
    real*8, intent(in) :: r, s, t
    real*8, dimension(:, :), intent(in) :: uv ! uv(1:2, 1:2)
    real*8, dimension(:), intent(in) :: x3, x4
    real*8, intent(out) :: x, y, z

    ! local vars
    real*8 :: u, v, alpha, u0
    real*8, dimension(3) :: Sf, xf, Sc
    !
    real*8, dimension(2) :: uv_fin 


    if ( abs(t - 1.0d0) <= 1.0d-15 ) then
       u = r ! simple
       v = s ! simple
    else 
       u = r/(1-t)
       v = s/(1-t)
    end if
    alpha = t

    ! compute final uv
    if ( abs(v - 1.0d0) <= 1.0d-15 ) then
       u0 = u ! simple
    else 
       u0 = u/(1-v)
    end if

    uv_fin = uv(:, 1) + u0 * (uv(:, 2) - uv(:, 1)) 

    ! compute surface points
    call Suv(u = uv_fin(1), v= uv_fin(2), S = Sc)

    Sf = v * x3 + (1.0d0 - v) * Sc

    xf = alpha * x4 + (1.0d0 - alpha) * Sf

    x = xf(1)
    y = xf(2)
    z = xf(3)

    ! done here
  end subroutine master2curved_edg_tet

  !
  ! This tests a set of three tetrahedrons
  ! that exhibit two possible cases of mounting
  ! on a curved surface:
  !
  ! 1 - one face on surface
  ! 2 - only one edge on the surface
  ! 
  ! a sphere is used as exact surface representation
  ! 
  subroutine tester1()
    implicit none

    ! local vars
    integer :: d, i
    real*8, dimension(:), allocatable :: r, s, t, x, y, z
    real*8, dimension(3) :: xA, x3, x4
    real*8, dimension(2, 3) :: uv

    ! generate the lagrangian tet. interpolation points
    d = 8
    call coord_tet(d, r, s, t)
    allocate(x(size(r)), y(size(r)), z(size(r))) 

    ! element 1
    xA = (/ .15d0, .15d0, 2.2d0 /)
    uv = reshape( (/ 0.0d0, 0.0d0, .5d0, 0.0d0 &
         , 0.0d0, 0.5d0 /), (/2, 3/) )

    do i = 1, size(r)
       call master2curved_tet( r = r(i), s = s(i), t = t(i), uv = uv &
            , xA = xA, x = x(i), y = y(i), z = z(i) )

       ! call master2curved_tet(r(i),s(i),t(i), xA, x(i), y(i), z(i))
    end do

    ! export the generated curved element
    call export_tet_face_curve(x = x, y=y, z=z, mina = 20.0d0 &
         , maxa = 155.0d0, fname = 'curved.tec', meshnum = 1, append_it = .false.)  

    ! element 2
    xA = (/ .38d0, .38d0, 2.2d0 /)
    uv = reshape( (/ 0.5d0, 0.0d0, 0.5d0, 0.5d0 &
         , 0.0d0, 0.5d0 /), (/2, 3/) )

    do i = 1, size(r)
       call master2curved_tet( r = r(i), s = s(i), t = t(i), uv = uv &
            , xA = xA, x = x(i), y = y(i), z = z(i) )

       ! call master2curved_tet(r(i),s(i),t(i), xA, x(i), y(i), z(i))
    end do

    ! export the generated curved element
    call export_tet_face_curve(x = x, y=y, z=z, mina = 20.0d0 &
         , maxa = 155.0d0, fname = 'curved.tec', meshnum = 2, append_it = .true.)  

    ! element 3
    xA = (/ .22d0, .22d0, 3.0d0 /)
    uv = reshape( (/ 0.5d0, 0.0d0, 0.0d0, 0.5d0 &
         , 0.0d0, 0.0d0 /), (/2, 3/) )
    x3 = (/ .15d0, .15d0, 2.2d0 /)
    x4 = (/ .38d0, .38d0, 2.2d0 /)

    do i = 1, size(r)
       call master2curved_edg_tet( r = r(i), s = s(i), t = t(i), uv = uv &
            , x3 = x3, x4 = x4, x = x(i), y = y(i), z = z(i) )
    end do

    ! export the generated curved element
    call export_tet_face_curve(x = x, y=y, z=z, mina = 20.0d0 &
         , maxa = 155.0d0, fname = 'curved.tec', meshnum = 3, append_it = .true.)  

    ! clean ups
    if ( allocated(r) ) deallocate(r)
    if ( allocated(s) ) deallocate(s)
    if ( allocated(t) ) deallocate(t)
    if ( allocated(x) ) deallocate(x)
    if ( allocated(y) ) deallocate(y)
    if ( allocated(z) ) deallocate(z)

    ! done here
  end subroutine tester1

  ! 
  subroutine curved_tetgen_geom(tetgen_cmd, facet_file, cad_file, nhole, xh, tol, tmpi)
    implicit none
    character(len = *), intent(in) :: tetgen_cmd, facet_file, cad_file
    integer, intent(in) :: nhole
    real*8, dimension(:), intent(in) :: xh
    real*8, intent(in) :: tol
    class(mpi_comm_t) :: tmpi

    ! local vars
    integer :: ii, jj
    integer :: npts, nquad, ntri
    real*8, dimension(:), allocatable :: x
    integer, dimension(:), allocatable :: icontag

    ! outs
    real*8, dimension(:, :), allocatable :: xf
    integer, dimension(:, :), allocatable :: tetcon, neigh
    integer :: nbntri
    integer, dimension(:), allocatable :: bntri
    ! integer, dimension(:, :), allocatable :: bntri2bntri
    type(int_array), dimension(:), allocatable :: node2bntri

    real*8, allocatable :: uu(:, :)

    ! domain decomposition (graph partitioning) vars
    integer, dimension(:), allocatable :: xadj, adj, vwgt, part
    integer :: nparts
    logical, dimension(:), allocatable :: vis_mask
    ! vars for boundary-based decomp
    integer, dimension(:), allocatable :: inter_elems, near_bn_elems
    integer, allocatable :: arrl(:), arrg(:)
    integer :: itet

    ! CAD corresponding data struct
    integer, allocatable :: cent_cad_found(:) !nbntri
    real*8, allocatable :: uvc(:)
    integer, dimension(:, :), allocatable :: tet_shifted
    integer, dimension(:), allocatable :: tet2bn_tri, tet_type
    ! integer :: neigh_CAD_face(3)
    logical :: is_CAD_bn_tri

    ! master element data struct
    integer :: dd, indx, CAD_face
    real*8, dimension(:), allocatable :: rr, ss, tt, xx, yy, zz
    real*8, dimension(3) :: xA
    real*8, dimension(3, 3) :: xbot

    ! visualization data struct
    real*8 :: xtet(3, 4), lens(6)
    real*8 :: ref_length
    character(len = 128) :: outname, this_cpu_wtime

    ! MPI data struct
    integer :: size_arr_on_root(2), len_bntri(1)
    real*8 :: tmp_time, root_max_timing(1)

    ! read the facet file
    print *, 'starting curved tetrahedral mesh generator'
    print *, 'reading the facet file ...'
    call read_facet_file(facet_file, npts, x, nquad, ntri, icontag)
    print *, 'the facet file read is complete!'

    ! !
    ! ! generic tetmesher subroutine
    ! !
    if ( tmpi%rank .eq. tmpi%root_rank ) then
       print *, 'generating initial tetmesh of whole domain ...'
       call tetmesh(tetgen_cmd, npts, x, nquad, ntri, icontag, nhole, xh &
            , xf, tetcon, neigh, nbntri, bntri)
       print *, 'initial tetmesh is done!'
    end if



    ! Broadcast the generated grid info
    !
    ! xf
    ! first pack the size info
    if ( tmpi%rank .eq. tmpi%root_rank ) then
       size_arr_on_root = (/ size(xf, 1), size(xf, 2) /)
    end if
    call tmpi%bcast_int(size_arr_on_root)
    ! then bcast the data
    if ( tmpi%rank .ne. tmpi%root_rank ) then
       allocate(xf(size_arr_on_root(1), size_arr_on_root(2)))
    end if
    do ii = 1, 3
       call tmpi%bcast_double(xf(ii, :))
    end do

    ! tetcon
    ! first pack the size info
    if ( tmpi%rank .eq. tmpi%root_rank ) then
       size_arr_on_root = (/ size(tetcon, 1), size(tetcon, 2) /)
    end if
    call tmpi%bcast_int(size_arr_on_root)
    ! then bcast the data
    if ( tmpi%rank .ne. tmpi%root_rank ) then
       allocate(tetcon(size_arr_on_root(1), size_arr_on_root(2)))
    end if
    do jj = 1, 4
       call tmpi%bcast_int(tetcon(:, jj))
    end do

    ! neigh
    ! first pack the size info
    if ( tmpi%rank .eq. tmpi%root_rank ) then
       size_arr_on_root = (/ size(neigh, 1), size(neigh, 2) /)
    end if
    call tmpi%bcast_int(size_arr_on_root)
    ! then bcast the data
    if ( tmpi%rank .ne. tmpi%root_rank ) then
       allocate(neigh(size_arr_on_root(1), size_arr_on_root(2)))
    end if
    do jj = 1, 4
       call tmpi%bcast_int(neigh(:, jj))
    end do

    ! bntri
    ! first pack the size info
    if ( tmpi%rank .eq. tmpi%root_rank ) len_bntri(1) = nbntri
    call tmpi%bcast_int(len_bntri)
    nbntri = len_bntri(1)
    if ( tmpi%rank .eq. tmpi%root_rank ) len_bntri(1) = size(bntri)
    call tmpi%bcast_int(len_bntri)
    ! alloc.
    if ( tmpi%rank .ne. tmpi%root_rank ) then
       allocate(bntri(len_bntri(1)))
    end if

    ! then bcast the data
    call tmpi%bcast_int(bntri)


    ! ! find the boundary tri connectivity map
    ! ! useful for speedup the code when deciding on
    ! ! UV-projection or closest point
    ! call find_bntri2bntri_map(nbntri = nbntri, bntri = bntri, bntri2bntri = bntri2bntri)

    ! ! bullet proofing ...
    ! if ( any ( bntri2bntri .eq. -1) ) then
    !    print *, 'boundary triangles are not all connected together! stop'
    !    stop
    ! end if

    allocate(node2bntri(size(xf, 2)))
    call find_node2bntri_map(nbntri = nbntri, bntri = bntri, node2bntri = node2bntri)


    ! ! export linear tetmesh
    ! allocate(uu(1, size(xf,2)))
    ! uu = 1.0d0
    ! call write_u_tecplot_tet(meshnum=1, outfile='linear_tets.tec', x = xf &
    !      , icon = tetcon, u = uu, appendit = .false.)
    ! if ( allocated(uu) ) deallocate(uu)


    ! find the CAD face of boundary triangles
    call find_bn_tris_CAD_face(cad_file = cad_file, nbntri = nbntri &
         , bntri = bntri, xf = xf, cent_cad_found = cent_cad_found &
         , uvc = uvc, tol = tol)


    ! prepare the output file name
    write (outname, "(A7,I0.3,A4)") "grdPART", tmpi%rank, ".tec"

    ! shift tetcon for each tet such that the first three nodes
    ! are matching the boundary triangle face. This is required
    ! before we apply our analytical transformation
    !
    allocate( tet_shifted(size(tetcon, 1), size(tetcon, 2)) )
    allocate( tet2bn_tri(size(tetcon, 1)), tet_type(size(tetcon, 1)) )

    call shift_tetcon(nbntri = nbntri, bntri = bntri &
         , tetcon = tetcon, tetcon2 = tet_shifted, tet2bn_tri = tet2bn_tri &
         , tet_type = tet_type, cent_cad_found = cent_cad_found)

    ! generate the lagrangian tet. interpolation points
    dd = 12
    call coord_tet(dd, rr, ss, tt)
    allocate(xx(size(rr)), yy(size(rr)), zz(size(rr))) 

! determine the type of load-balance
if ( LOAD_BALANCE_BASED_ON_BOUNDARY ) then

   ! determine interior and boundary elems
   call decomp_based_on_bn(tet_type = tet_type, inter_elems = inter_elems &
        , near_bn_elems = near_bn_elems)

   ! init
   indx = 1
   ! timing
   tmp_time = wtime()

   ! decomp near boundary elems
   call equal_decomp_nelem_by_np(nelem = size(near_bn_elems) &
        , np = tmpi%np, arr = arrl)
   call loc2glob_indx(arrl = arrl, arrg = arrg)

   ! only do its portion of this process rank
   do itet = arrg(tmpi%rank+1), (arrg(tmpi%rank+2)-1) 
      ii = near_bn_elems(itet) ! get tet number

      ! pick the appex of the tet required for some mappings
      xA = xf(:, tet_shifted(ii, 4))

      ! compute xbot
      do jj = 1, 3
         xbot(:, jj) = xf(:, tet_shifted(ii, jj))
      end do

      ! fill this tet coords
      do jj = 1, 4
         xtet(:, jj) = xf(:, tet_shifted(ii,jj))
      end do

      select case ( tet_type(ii) )

      case ( 0 ) ! interior, use linear (straight map)
         ! do nothing at this point

      case ( 1 ) ! one face (tri) of the tet on CAD boundary

         ! bullet proofing ...
         if ( tet2bn_tri(ii) .eq. -1 ) then
            print *, 'This tet is supposed to be one-face-bn' &
                 , ' tet but is NOT! stop'
            stop
         end if

         ! 
         CAD_face = cent_cad_found(tet2bn_tri(ii))
         ! bullet proofing ...
         if ( CAD_face .eq. -1 ) then !bn tet not on CAD database 
            print *, 'this boundary-face tet has a CAD face' &
                 , ' tag equal to -1! stop'
            stop
         end if


         is_CAD_bn_tri = is_tri_near_CAD_boundary(node2bntri = node2bntri &
              , CAD_face = cent_cad_found, nodes = tet_shifted(ii, 1:3))

         do jj = 1, size(rr)

            if ( .not.  is_CAD_bn_tri) then
               call master2curved_tet_ocas_close(r = rr(jj),s = ss(jj),t = tt(jj) &
                    , xbot = xbot, xA = xA, tol = tol, x = xx(jj), y = yy(jj) &
                    , z = zz(jj) &
                    , CAD_face_input = CAD_face)

            else

               call master2curved_tet_ocas_close(r = rr(jj),s = ss(jj),t = tt(jj) &
                    , xbot = xbot, xA = xA, tol = tol, x = xx(jj) &
                    , y = yy(jj), z = zz(jj))

            end if

         end do


      case (2) ! one-edge-curved-on-CAD tet


         do jj = 1, size(rr)
            call master2curved_edg_tet_ocas_close(r= rr(jj),s= ss(jj),t= tt(jj) &
                 , xyz = xtet, x = xx(jj), y = yy(jj), z = zz(jj), tol = tol)
         end do

      case default

         print *, 'unknown tet_type happened! stop'
         stop

      end select

!       ! export the generated curved element
!       call tetrahedron_edge_length ( tetra = xtet, edge_length = lens)
!       ref_length = 1.5d0 * maxval(lens) / dble(dd)

!       if ( indx .eq. 1) then
!          call export_tet_face_curve(x = xx, y=yy, z=zz, mina = 0.0d0 &
!               , maxa = 160.0d0, fname = trim(outname) &
!               , meshnum = indx, append_it = .false., ref_length = ref_length)  
!       else
!          call export_tet_face_curve(x = xx, y=yy, z=zz, mina = 0.0d0 &
!               , maxa = 160.0d0, fname = trim(outname) &
!               , meshnum = indx, append_it = .true., ref_length = ref_length) 
!       end if

      indx = indx + 1

      ! echo the status
      print *, 'still boundary elems, indx = ', indx, 'on CPU = ', tmpi%rank

   end do

! call tmpi%barrier()

   ! finally, decomp interior elems
   call equal_decomp_nelem_by_np(nelem = size(inter_elems) &
        , np = tmpi%np, arr = arrl)
   call loc2glob_indx(arrl = arrl, arrg = arrg)

   ! only do its portion of this process rank
   do itet = arrg(tmpi%rank+1), (arrg(tmpi%rank+2)-1) 
      ii = inter_elems(itet) ! get tet number

      ! pick the appex of the tet required for some mappings
      xA = xf(:, tet_shifted(ii, 4))

      ! compute xbot
      do jj = 1, 3
         xbot(:, jj) = xf(:, tet_shifted(ii, jj))
      end do

      ! fill this tet coords
      do jj = 1, 4
         xtet(:, jj) = xf(:, tet_shifted(ii,jj))
      end do

      select case ( tet_type(ii) )

      case ( 0 ) ! interior, use linear (straight map)

         do jj = 1, size(rr)
            call master2curved_tet_straight(r= rr(jj),s = ss(jj),t= tt(jj) &
                 , xbot = xbot, xA = xA, x = xx(jj), y = yy(jj), z = zz(jj))
         end do


      case ( 1 ) ! one face (tri) of the tet on CAD boundary

         ! do nothing at this point


      case (2) ! one-edge-curved-on-CAD tet

         ! do nothing at this point

      case default

         print *, 'unknown tet_type happened! stop'
         stop

      end select

!       ! export the generated curved element
!       call tetrahedron_edge_length ( tetra = xtet, edge_length = lens)
!       ref_length = 1.5d0 * maxval(lens) / dble(dd)

!       if ( indx .eq. 1) then
!          call export_tet_face_curve(x = xx, y=yy, z=zz, mina = 0.0d0 &
!               , maxa = 160.0d0, fname = trim(outname) &
!               , meshnum = indx, append_it = .false., ref_length = ref_length)  
!       else
!          call export_tet_face_curve(x = xx, y=yy, z=zz, mina = 0.0d0 &
!               , maxa = 160.0d0, fname = trim(outname) &
!               , meshnum = indx, append_it = .true., ref_length = ref_length) 
!       end if

      indx = indx + 1

      ! echo the status
      print *, 'interior elems, indx = ', indx, 'on CPU = ', tmpi%rank

   end do


else !LOAD-BALANCE

    ! setup vars for domain decomposition using METIS
    nparts = tmpi%np
    allocate(vwgt(size(neigh, 1)), part(size(neigh, 1)))
    vwgt = 1
    do jj = 1, size(vwgt)
       if (tet_type(jj) .ne. 0) then
          vwgt(jj) = 1
       end if
    end do

    call find_tet_adj_csr_zero_based(neigh = neigh, xadj = xadj, adj = adj)
    call call_metis_graph_parti(xadj = xadj, adjncy = adj, vwgt = vwgt &
         , nparts = nparts, part = part)

    ! ! write to tecplot
    ! allocate(vis_mask(size(neigh, 1)))
    ! allocate(uu(1, size(xf,2)))
    ! do ii = 1, nparts

    !    uu = dble(ii)
    !    vis_mask = (part .eq. (ii-1))

    !    if ( ii .eq. 1) then
    !       call write_u_tecplot_tet(meshnum=ii, outfile='partitioned.tec', x = xf &
    !            , icon = tetcon, u = uu, appendit = .false., is_active = vis_mask)
    !    else
    !       call write_u_tecplot_tet(meshnum=ii, outfile='partitioned.tec', x = xf &
    !            , icon = tetcon, u = uu, appendit = .true., is_active = vis_mask)
    !    end if

    ! end do
    ! if ( allocated(uu) ) deallocate(uu)
    ! if ( allocated(vis_mask) ) deallocate(vis_mask)


    ! init
    indx = 1

    ! timing
    tmp_time = wtime()

    ! map tets
    main_loop:    do ii = 1, size(tetcon, 1)

       ! skip if not in right CPU
       if ( tmpi%np > 1 ) then
          if ( tmpi%rank .ne. part(ii) ) cycle ! not in this CPU
       end if


       ! pick the appex of the tet required for some mappings
       xA = xf(:, tet_shifted(ii, 4))

       ! compute xbot
       do jj = 1, 3
          xbot(:, jj) = xf(:, tet_shifted(ii, jj))
       end do

       ! fill this tet coords
       do jj = 1, 4
          xtet(:, jj) = xf(:, tet_shifted(ii,jj))
       end do

       select case ( tet_type(ii) )

       case ( 0 ) ! interior, use linear (straight map)

          do jj = 1, size(rr)
             call master2curved_tet_straight(r= rr(jj),s = ss(jj),t= tt(jj) &
                  , xbot = xbot, xA = xA, x = xx(jj), y = yy(jj), z = zz(jj))
          end do

       case ( 1 ) ! one face (tri) of the tet on CAD boundary

          ! bullet proofing ...
          if ( tet2bn_tri(ii) .eq. -1 ) then
             print *, 'This tet is supposed to be one-face-bn' &
                  , ' tet but is NOT! stop'
             stop
          end if

          ! 
          CAD_face = cent_cad_found(tet2bn_tri(ii))
          ! bullet proofing ...
          if ( CAD_face .eq. -1 ) then !bn tet not on CAD database 
             print *, 'this boundary-face tet has a CAD face' &
                  , ' tag equal to -1! stop'
             stop
          end if


          is_CAD_bn_tri = is_tri_near_CAD_boundary(node2bntri = node2bntri &
               , CAD_face = cent_cad_found, nodes = tet_shifted(ii, 1:3))

          do jj = 1, size(rr)

             if ( .not.  is_CAD_bn_tri) then
                call master2curved_tet_ocas_close(r = rr(jj),s = ss(jj),t = tt(jj) &
                     , xbot = xbot, xA = xA, tol = tol, x = xx(jj), y = yy(jj), z = zz(jj) &
                     , CAD_face_input = CAD_face)

             else

                call master2curved_tet_ocas_close(r = rr(jj),s = ss(jj),t = tt(jj) &
                     , xbot = xbot, xA = xA, tol = tol, x = xx(jj), y = yy(jj), z = zz(jj))

             end if

          end do


       case (2) ! one-edge-curved-on-CAD tet


          do jj = 1, size(rr)
             call master2curved_edg_tet_ocas_close(r= rr(jj),s= ss(jj),t= tt(jj) &
                  , xyz = xtet, x = xx(jj), y = yy(jj), z = zz(jj), tol = tol)
          end do

       case default

          print *, 'unknown tet_type happened! stop'
          stop

       end select

       ! export the generated curved element
       call tetrahedron_edge_length ( tetra = xtet, edge_length = lens)
       ref_length = 1.5d0 * maxval(lens) / dble(dd)

       if ( indx .eq. 1) then
          call export_tet_face_curve(x = xx, y=yy, z=zz, mina = 0.0d0 &
               , maxa = 160.0d0, fname = trim(outname) &
               , meshnum = indx, append_it = .false., ref_length = ref_length)  
       else
          call export_tet_face_curve(x = xx, y=yy, z=zz, mina = 0.0d0 &
               , maxa = 160.0d0, fname = trim(outname) &
               , meshnum = indx, append_it = .true., ref_length = ref_length) 
       end if

       indx = indx + 1

       ! echo the status
       print *, 'indx = ', indx, 'on CPU = ', tmpi%rank

    end do main_loop

end if ! LOAD-BALANCE

! call tmpi%barrier()
    ! timing
    tmp_time = wtime() - tmp_time

    ! write the time of this process 
    write (this_cpu_wtime, "(A9,I0.3,A5)") "cpu_wtime", tmpi%rank, ".time"
    open (unit=22, file=this_cpu_wtime, status='unknown', action='write')
    write(22, *) tmp_time
    close(22)

    ! reduce all timings on root
    call tmpi%reduce_max_double((/ tmp_time /), root_max_timing )

    ! write the parallel time to
    ! the output file on the root 
    ! process 
    if ( tmpi%rank .eq. tmpi%root_rank ) then
       open (unit=30, file='root_wtime.txt', status='unknown', action='write')
       write(30, *) root_max_timing(1)
       close(30) 
    end if

    ! clean ups
    if ( allocated(x) ) deallocate(x)
    if ( allocated(icontag) ) deallocate(icontag)
    if ( allocated(xf) ) deallocate(xf)
    if ( allocated(tetcon) ) deallocate(tetcon)
    if ( allocated(neigh) ) deallocate(neigh)
    if ( allocated(bntri) ) deallocate(bntri)

!     do jj = 1, size(node2bntri)
!        if ( allocated(node2bntri(jj)%val) ) deallocate(node2bntri(jj)%val)
!     end do
!     if ( allocated(node2bntri) ) deallocate(node2bntri)

    if ( allocated(uu) ) deallocate(uu)
    if ( allocated(xadj) ) deallocate(xadj)
    if ( allocated(adj) ) deallocate(adj)
    if ( allocated(vwgt) ) deallocate(vwgt)
    if ( allocated(part) ) deallocate(part)
    if ( allocated(vis_mask) ) deallocate(vis_mask)
    if ( allocated(inter_elems) ) deallocate(inter_elems)
    if ( allocated(near_bn_elems) ) deallocate(near_bn_elems)
    if ( allocated(arrl) ) deallocate(arrl)
    if ( allocated(arrg) ) deallocate(arrg)
    if ( allocated(cent_cad_found) ) deallocate(cent_cad_found)
    if ( allocated(uvc) ) deallocate(uvc)
    if ( allocated(tet_shifted) ) deallocate(tet_shifted)
    if ( allocated(tet2bn_tri) ) deallocate(tet2bn_tri)
    if ( allocated(tet_type) ) deallocate(tet_type)
    if ( allocated(rr) ) deallocate(rr)
    if ( allocated(ss) ) deallocate(ss)
    if ( allocated(tt) ) deallocate(tt)
    if ( allocated(xx) ) deallocate(xx)
    if ( allocated(yy) ) deallocate(yy)
    if ( allocated(zz) ) deallocate(zz)

    ! done here
  end subroutine curved_tetgen_geom

  subroutine find_bn_tris_CAD_face(cad_file, nbntri, bntri, xf &
       , cent_cad_found, uvc, tol)
    implicit none
    character(len=*), intent(in) :: cad_file
    integer, intent(in) :: nbntri
    integer, dimension(:), intent(in) :: bntri
    real*8, dimension(:, :), intent(in) :: xf
    integer, allocatable :: cent_cad_found(:) !nbntri
    real*8, allocatable :: uvc(:)
    real*8, intent(in) :: tol

    ! local vars
    ! CAD corresponding data struct
    real*8, allocatable :: xc(:)
    integer :: tpt, ii, jj, kk
    real*8 :: tuv(2), txyz(3), xbn(3,3)

    ! init CAD file
    call init_IGES_f90(fname = cad_file)

    ! find the CAD tag of the centroid of bn faces (tris)
    if ( allocated(cent_cad_found) ) deallocate(cent_cad_found)
    allocate(cent_cad_found(nbntri))
    cent_cad_found = 0

    allocate(xc(3*nbntri))
    xc = 0.0d0

    if ( allocated(uvc) ) deallocate(uvc)
    allocate(uvc(2*nbntri))
    uvc = 0.0d0

    do ii = 1, nbntri
       do jj = 1, 3
          tpt = bntri(6*(ii-1) + jj)
          do kk = 1, 3
             xc(3*(ii-1) + kk) = xc(3*(ii-1) + kk) + xf(kk, tpt)
          end do
       end do
    end do

    ! finalize the center coord
    xc = xc / 3.0d0 
    ! find the CAD tag of the centroids
    print *, 'find the CAD tag of the centroids'
    call find_pts_on_database_f90(npts = nbntri, pts = xc &
         , found = cent_cad_found, uv = uvc, tol = tol)

    ! compute physical center of bn tris and export to MATLAB ...
!     open (unit=10, file='tmp.m', status='unknown', action='write')
!     write(10, *) 'x = ['
    do ii = 1, nbntri
       tuv(1) = uvc(2*(ii-1) + 1)
       tuv(2) = uvc(2*(ii-1) + 2)
       if (cent_cad_found(ii) .eq. -1) cycle
       call uv2xyz_f90(CAD_face = cent_cad_found(ii), uv = tuv, xyz = txyz)
       print *, 'writing the center of bntri #', ii
!        write(10, *) txyz, ';'
    end do
!     write(10, *) '];'

    ! print mapped bn triangles
!     write(10, *) 'tris = ['
    do ii = 1, nbntri
       if (cent_cad_found(ii) .eq. -1) cycle
       do jj = 1, 3
          tpt = bntri(6*(ii-1) + jj)
          xbn(:, jj) = xf(:, tpt)
       end do
!        write(10, *) xbn(:, 1), ';'
!        write(10, *) xbn(:, 2), ';'
!        write(10, *) xbn(:, 3), ';'
!        write(10, *) xbn(:, 1), ';' 
       ! print*, ' '
    end do
!     write(10, *) '];'
!     close(10)


    ! close CAD objects
    !call clean_statics_f90()

    ! cleanups
    if ( allocated(xc) ) deallocate(xc)

    ! done here
  end subroutine find_bn_tris_CAD_face

  !
  subroutine find_tet_adj_csr_zero_based(neigh, xadj, adj)
    implicit none
    integer, dimension(:, :), intent(in) :: neigh
    integer, dimension(:), allocatable :: xadj, adj

    ! local vars
    integer :: ii, jj, nadj, indx

    ! counting and sizing
    nadj = 0
    do ii = 1, size(neigh, 1) ! loop over all tets 
       do jj = 1, size(neigh, 2) ! over neighbors
          if (neigh(ii, jj) > 0 ) nadj = nadj + 1
       end do
    end do

    ! alloc
    if ( allocated(xadj) ) deallocate(xadj)
    allocate(xadj(size(neigh, 1)+1))
    if ( allocated(adj) ) deallocate(adj)
    allocate(adj(nadj))

    ! fill them
    xadj(1) = 0
    indx = 1
    do ii = 1, size(neigh, 1) 
       do jj = 1, size(neigh, 2)
          if (neigh(ii, jj) > 0 ) then
             adj(indx) = neigh(ii, jj)
             indx = indx + 1
          end if
       end do
       xadj(ii+1) = indx - 1
    end do

    adj = adj - 1 ! zero-based cell number

    ! done here
  end subroutine find_tet_adj_csr_zero_based

  !
  subroutine call_metis_graph_parti(xadj, adjncy, vwgt, nparts, part)
    implicit none
    integer, intent(in) :: xadj(:), adjncy(:), vwgt(:)
    integer, intent(in) :: nparts
    integer, intent(out) :: part(:)


    ! local vars
    integer :: nvtxs, ncon
    integer, pointer :: vsize(:) =>null(), adjwgt(:) =>null()
    real*8, pointer :: tpwgts(:)=>null(), ubvec=>null()
    integer, pointer :: options(:) =>null()
    integer :: edgecut

    ! init
    nvtxs = size(xadj) - 1
    ncon = 1

    ! call C-func
    call METIS_PartGraphRecursive(nvtxs, ncon, xadj &
         ,adjncy, vwgt, vsize, adjwgt & 
         ,nparts, tpwgts, ubvec, options & 
         ,edgecut, part)

    ! done here
  end subroutine call_metis_graph_parti

  !
  subroutine shift_tetcon(nbntri, bntri, tetcon, tetcon2, tet2bn_tri, tet_type, cent_cad_found)
    implicit none
    integer, intent(in) :: nbntri
    integer, dimension(:), intent(in), target :: bntri
    integer, dimension(:, :), intent(in) :: tetcon
    integer, dimension(:, :), intent(out) :: tetcon2
    integer, dimension(:), intent(out) :: tet2bn_tri, tet_type
    integer, dimension(:), intent(in) :: cent_cad_found

    ! local vars
    integer :: ii, i1, i2, tetnum, jj, kk
    integer, dimension(:), pointer :: pts => null(), tets_on_face => null()
    integer :: edg(2)
    integer, allocatable :: tets(:)

    ! init
    tet2bn_tri = -1
    tet_type = 0 ! default interior
    tetcon2 = tetcon

    ! shift the tets that have one face on CAD boundary
    do ii = 1, nbntri

       if ( cent_cad_found(ii) .eq. -1 ) cycle

       i1 = 6* (ii-1) + 1
       i2 = 6* (ii-1) + 3

       pts => bntri(i1:i2)  

       i1 = 6* (ii-1) + 5
       i2 = 6* (ii-1) + 6

       tets_on_face => bntri(i1:i2)

       tetnum = maxval(tets_on_face)
       if ( tetnum > size(tetcon, 1) ) tetnum = minval(tets_on_face)
       if ( tetnum <= 0 ) then
          print *, 'fatal; tetnum <= 0. stop'
          stop
       end if

       tet2bn_tri(tetnum) = ii
       tet_type(tetnum) = 1 ! one face on CAD

       ! bullet proofing ...
       if ( .not. a_in_b(a = pts, b = tetcon(tetnum, :)) ) then
          print *, 'Not all boundary tri points are in the given tet!!! stop'
          stop
       end if

       !
       call shift_tet_to_bn_tri(tet0 = tetcon(tetnum, :), tri = pts &
            , tet = tetcon2(tetnum, :))
    end do

    ! shift tets that have one edge on the CAD boundary
    do ii = 1, nbntri

       if ( cent_cad_found(ii) .eq. -1 ) cycle

       i1 = 6* (ii-1) + 1
       i2 = 6* (ii-1) + 3

       pts => bntri(i1:i2)  


       do jj = 1, 3

          if ( jj < 3 ) then
             edg = (/ pts(jj+1), pts(jj) /)
          else
             edg = (/ pts(1), pts(3) /)
          end if

          call tets_cont_edge(tetcon = tetcon, edg = edg, tets = tets)

          do kk = 1, size(tets)
             if (tet_type(tets(kk)) .eq. 0 ) then
                tet_type(tets(kk)) = 2 ! one edge on CAD

                call shift_tet_to_edg_on_bn(tet0 = tetcon(tets(kk), :), edg =  edg&
                     , tet = tetcon2(tets(kk), :))
             end if
          end do
       end do

    end do

    ! cleanups
    if ( allocated(tets) ) deallocate(tets)

    ! done here
  end subroutine shift_tetcon

  ! checks see if array(set) <a> is
  ! in array <b>. order is not important.
  ! if "yes" then returns .true. otherwise
  ! returns .false.
  ! 
  function a_in_b(a, b)
    implicit none
    integer, dimension(:), intent(in) :: a, b
    logical :: a_in_b

    ! local vars
    integer :: ii, jj

    do ii = 1, size(a)
       a_in_b = .false.
       do jj = 1, size(b)
          if ( a(ii) .eq. b(jj) ) then
             a_in_b = .true.
             exit
          end if
       end do
       if ( .not. a_in_b ) exit
    end do

    ! done here
  end function a_in_b

  !
  subroutine shift_tet_to_bn_tri(tet0, tri, tet)
    implicit none
    integer, dimension(:), intent(in) :: tet0, tri
    integer, dimension(:), intent(out) :: tet

    ! local vars
    integer :: ii, jj, loc
    logical :: found

    ! init copy
    tet = tet0

    ! first find which tet0(:) point is
    ! not in tri(:). That's the tet's appex.
    ! Then set that as "loc" for shift to right.
    ! The appex should always go to the last
    ! location in connectivity array of the tet
    ! at the end when shifting is complete.

    do ii = 1, 4 

       found = .false.
       do jj = 1, 3
          if ( tri(jj) .eq. tet(ii) ) then
             found = .true.
             exit
          end if
       end do

       if ( .not. found ) then
          loc = ii
          exit
       end if

    end do

    ! Now, shift to right accordingly
    !
    tet = cshift(tet, (ii-4))

    ! done here
  end subroutine shift_tet_to_bn_tri

  ! tetrahedrals containing the edge
  subroutine tets_cont_edge(tetcon, edg, tets)
    implicit none
    integer, dimension(:, :), intent(in) :: tetcon
    integer, dimension(:), intent(in) :: edg !(1:2)
    integer, dimension(:), allocatable :: tets 

    ! local vars
    integer :: i

    ! bullet proofing
    if ( allocated(tets) ) deallocate(tets)

    do i = 1, size(tetcon, 1)

       if ( a_in_b(edg, tetcon(i, :)) ) then

          call push_int_2_array(a = tets, i = i)

       end if

    end do

    ! done here
  end subroutine tets_cont_edge

  !
  subroutine shift_tet_to_edg_on_bn(tet0, edg, tet)
    implicit none
    integer, dimension(:), intent(in) :: tet0, edg
    integer, dimension(:), intent(out) :: tet

    ! local vars
    integer :: i, indx, others(2)

    indx = 1
    do i = 1, 4
       if ( all(tet0(i) .ne. edg) ) then
          others(indx) = tet0(i)
          indx = indx + 1
       end if
       if ( indx .eq. 3 ) exit
    end do

    ! bullet proofing ...
    if ( indx .ne. 3 ) then
       print *, 'this edg in not in the given tet! stop'
       stop
    end if

    ! rearrange them in correct format
    tet = (/ edg, others /) 

    ! done here
  end subroutine shift_tet_to_edg_on_bn

  subroutine Suv_ocas(uv, CAD_face, S)
    implicit none
    real*8, dimension(:), intent(in) :: uv
    integer, intent(in) :: CAD_face
    real*8, dimension(:), intent(out) :: S

    call uv2xyz_f90(CAD_face = CAD_face, uv = uv, xyz = S)

    ! done here
  end subroutine Suv_ocas

  subroutine master2curved_tet_ocas(CAD_face, r,s,t, uv, xA, x, y, z)
    implicit none
    integer, intent(in) :: CAD_face
    real*8, intent(in) :: r, s, t
    real*8, dimension(:, :), intent(in) :: uv
    real*8, dimension(:), intent(in) :: xA
    real*8, intent(out) :: x, y, z

    ! local vars
    integer :: ii
    real*8 :: u, v, alpha
    real*8, dimension(3) :: Sf, xf
    !
    real*8 :: val   ! the value of basis  
    real*8, dimension(2) :: der, uv_fin 


    if ( abs(t - 1.0d0) <= 1.0d-15 ) then
       u = r ! simple
       v = s ! simple
    else 
       u = r/(1-t)
       v = s/(1-t)
    end if
    alpha = t

    ! compute final uv
    uv_fin = 0.0d0
    do ii = 1, 3
       call psi(etype = 1, i = ii, r = u, s = v, val = val, der = der)
       uv_fin = uv_fin + val * uv(:, ii)
    end do

    ! compute surface points
    ! call Suv(u = uv_fin(1), v= uv_fin(2), S = Sf)
    call Suv_ocas(uv = uv_fin, CAD_face = CAD_face, S = Sf)

    xf = alpha * xA + (1.0d0 - alpha) * Sf

    x = xf(1)
    y = xf(2)
    z = xf(3)

    ! done here
  end subroutine master2curved_tet_ocas

  subroutine master2curved_tet_ocas_close(r,s,t, xbot, xA, tol, x, y, z, CAD_face_input)
    implicit none
    real*8, intent(in) :: r, s, t
    real*8, dimension(:, :), intent(in) :: xbot
    real*8, dimension(:), intent(in) :: xA
    real*8, intent(in) :: tol
    real*8, intent(out) :: x, y, z
    integer, intent(in), optional :: CAD_face_input

    ! local vars
    integer :: ii, CAD_face(1)
    real*8 :: u, v, alpha
    real*8, dimension(3) :: Sf, xf, xbot_fin
    !
    real*8 :: val   ! the value of basis  
    real*8, dimension(2) :: der, uvout  


    if ( abs(t - 1.0d0) <= 1.0d-15 ) then
       u = r ! simple
       v = s ! simple
    else 
       u = r/(1-t)
       v = s/(1-t)
    end if
    alpha = t

    ! compute final xbot
    xbot_fin = 0.0d0
    do ii = 1, 3
       call psi(etype = 1, i = ii, r = u, s = v, val = val, der = der)
       xbot_fin = xbot_fin + val * xbot(:, ii)
    end do

    ! compute surface points
    ! call Suv(u = uv_fin(1), v= uv_fin(2), S = Sf)
    ! call Suv_ocas(uv = uv_fin, CAD_face = CAD_face, S = Sf)
    if ( .not. present(CAD_face_input) ) then
       ! ! WORKING
       call find_pts_on_database_f90(npts = 1, pts = xbot_fin, found = CAD_face, uv = uvout, tol = tol)
       if ( CAD_face(1) .eq. -1 ) then
          print *, 'CAD_face .eq. -1 in master2curved_tet_ocas_close(...)! increase tolerance! stop'
          stop
       end if

       call uv2xyz_f90(CAD_face = CAD_face(1), uv = uvout, xyz = Sf)
       ! ! END WORKING
    else

       call xyz2close_xyz_f90(CAD_face = CAD_face_input, xyz = xbot_fin, close_xyz = Sf, tol = tol)

    end if

    xf = alpha * xA + (1.0d0 - alpha) * Sf

    x = xf(1)
    y = xf(2)
    z = xf(3)

    ! done here
  end subroutine master2curved_tet_ocas_close

  ! subroutine find_bntri2bntri_map(nbntri, bntri, bntri2bntri)
  !   implicit none
  !   integer, intent(in) :: nbntri
  !   integer, dimension(:), intent(in) :: bntri
  !   integer, dimension(:, :), allocatable :: bntri2bntri

  !   ! local vars
  !   integer :: i, i1, i2
  !   integer, allocatable :: bn(:, :) ! bn(1:nbntri, 1:3nodes)

  !   allocate(bn(nbntri, 3))
  !   if (allocated(bntri2bntri) ) deallocate(bntri2bntri)
  !   allocate(bntri2bntri(nbntri, 3))

  !   ! extract "bntri" to a 2d array bn(1:nbntri, 1:3nodes)
  !   ! for ease of work and readability
  !   do i = 1, nbntri
  !      i1 = 6*(i-1) + 1
  !      i2 = 6*(i-1) + 3
  !      bn(i , :) = bntri(i1:i2)
  !   end do

  !   ! now, proceed to fill the output bntri2bntri array
  !   ! using "bn" array info
  !   !
  !   do i = 1, nbntri
  !      bntri2bntri(i, 1) = find_tri_has(bn, i, (/ bn(i, 2), bn(i, 3) /) )
  !      bntri2bntri(i, 2) = find_tri_has(bn, i, (/ bn(i, 3), bn(i, 1) /) )
  !      bntri2bntri(i, 3) = find_tri_has(bn, i, (/ bn(i, 1), bn(i, 2) /) )
  !   end do

  !   ! clean ups
  !   if ( allocated(bn) ) deallocate(bn)

  !   ! done here

  ! contains

  !   function find_tri_has(bn, tri, edg)
  !     implicit none
  !     integer, dimension(:, :) , intent(in) :: bn
  !     integer, intent(in) :: tri
  !     integer, dimension(:), intent(in) :: edg
  !     integer :: find_tri_has

  !     ! local vars
  !     integer :: i, j, cnt

  !     ! init 
  !     find_tri_has = -1 !not found= wall

  !     do i = 1, size(bn, 1)

  !        if ( i .eq. tri ) cycle

  !        cnt = 0
  !        do j = 1, 3
  !           if ( any(bn(i, j) .eq. edg) ) cnt = cnt + 1
  !        end do

  !        if ( cnt .eq. 2) then
  !           find_tri_has = i
  !           exit
  !        end if

  !     end do

  !     ! done here
  !   end function find_tri_has

  ! end subroutine find_bntri2bntri_map

  subroutine find_node2bntri_map(nbntri, bntri, node2bntri)
    implicit none
    integer, intent(in) :: nbntri
    integer, dimension(:), intent(in), target :: bntri
    type(int_array), dimension(:) :: node2bntri

    ! local vars
    integer :: i, i1, i2, j
    integer, pointer :: nodes(:) => null()

    do i = 1, nbntri
       i1 = 6*(i-1) + 1
       i2 = 6*(i-1) + 3
       nodes => bntri(i1:i2)
       do j = 1, 3
          call push_int_2_array(node2bntri(nodes(j))%val, i)
       end do
    end do

    ! done here
  end subroutine find_node2bntri_map

  function is_tri_near_CAD_boundary(node2bntri, CAD_face, nodes)
    implicit none
    type(int_array), dimension(:), intent(in), target :: node2bntri
    integer, dimension(:), intent(in) :: CAD_face, nodes
    logical :: is_tri_near_CAD_boundary

    ! local vars
    integer :: inode, ref
    integer, pointer :: cells(:) => null()

    is_tri_near_CAD_boundary = .false.
    ref = CAD_face(node2bntri(nodes(1))%val(1))

    do inode = 1, size(nodes)
       cells => node2bntri(nodes(inode))%val

       if ( .not. all(ref .eq. CAD_face(cells)) ) then
          is_tri_near_CAD_boundary = .true.
          exit
       end if
    end do

    ! done here
  end function is_tri_near_CAD_boundary

  subroutine master2curved_edg_tet_ocas_close(r,s,t, xyz, x, y, z, tol)
    implicit none
    real*8, intent(in) :: r, s, t
    real*8, dimension(:, :), intent(in) :: xyz
    real*8, intent(out) :: x, y, z
    real*8, intent(in) :: tol

    ! local vars
    real*8 :: u, v, alpha, u0
    real*8, dimension(3) :: Sf, xf, Sc
    !
    real*8, dimension(3) :: xyz_fin, x1, x2, x3, x4 
    integer :: CAD_face(1)
    real*8 :: uvout(2)

    ! init
    x1 = xyz(:,1)
    x2 = xyz(:,2)
    x3 = xyz(:,3)
    x4 = xyz(:,4)

    if ( abs(t - 1.0d0) <= 1.0d-15 ) then
       u = r ! simple
       v = s ! simple
    else 
       u = r/(1-t)
       v = s/(1-t)
    end if
    alpha = t

    ! compute final uv
    if ( abs(v - 1.0d0) <= 1.0d-15 ) then
       u0 = u ! simple
    else 
       u0 = u/(1-v)
    end if

    ! uv_fin = uv(:, 1) + u0 * (uv(:, 2) - uv(:, 1)) 
    xyz_fin = x1 + u0 * (x2 - x1) 

    call find_pts_on_database_f90(npts = 1, pts = xyz_fin, found = CAD_face, uv = uvout, tol = tol)
    if ( CAD_face(1) .eq. -1 ) then
       print *, 'CAD_face .eq. -1 in master2curved_edg_tet_ocas_close(...)! increase tolerance! stop'
       stop
    end if

    call uv2xyz_f90(CAD_face = CAD_face(1), uv = uvout, xyz = Sc)

    ! ! compute surface points
    ! call Suv(u = uv_fin(1), v= uv_fin(2), S = Sc)

    Sf = v * x3 + (1.0d0 - v) * Sc

    xf = alpha * x4 + (1.0d0 - alpha) * Sf

    x = xf(1)
    y = xf(2)
    z = xf(3)

    ! done here
  end subroutine master2curved_edg_tet_ocas_close

  subroutine master2curved_tet_straight(r,s,t, xbot, xA, x, y, z)
    implicit none
    real*8, intent(in) :: r, s, t
    real*8, dimension(:, :), intent(in) :: xbot
    real*8, dimension(:), intent(in) :: xA
    real*8, intent(out) :: x, y, z

    ! local vars
    integer :: ii
    real*8 :: u, v, alpha
    real*8, dimension(3) :: Sf, xf, xbot_fin
    !
    real*8 :: val   ! the value of basis  
    real*8, dimension(2) :: der  


    if ( abs(t - 1.0d0) <= 1.0d-15 ) then
       u = r ! simple
       v = s ! simple
    else 
       u = r/(1-t)
       v = s/(1-t)
    end if
    alpha = t

    ! compute final xbot
    xbot_fin = 0.0d0
    do ii = 1, 3
       call psi(etype = 1, i = ii, r = u, s = v, val = val, der = der)
       xbot_fin = xbot_fin + val * xbot(:, ii)
    end do

    Sf = xbot_fin

    xf = alpha * xA + (1.0d0 - alpha) * Sf

    x = xf(1)
    y = xf(2)
    z = xf(3)

    ! done here
  end subroutine master2curved_tet_straight

  !
  subroutine decomp_based_on_bn(tet_type, inter_elems, near_bn_elems)
    implicit none
    integer, dimension(:), intent(in) :: tet_type
    integer, dimension(:), allocatable :: inter_elems, near_bn_elems

    !local vars
    integer :: ii, nint, nbn

    ! count interior and near boundary elems
    nint = 0
    nbn = 0
    do ii = 1, size(tet_type)
       if ( tet_type(ii) .eq. 0 ) then
          nint = nint + 1
       else
          nbn = nbn + 1
       end if
    end do

    ! size them
    if ( allocated(inter_elems) ) deallocate(inter_elems)
    allocate( inter_elems(nint) )
    if ( allocated(near_bn_elems) ) deallocate(near_bn_elems)
    allocate( near_bn_elems(nbn) )

    ! fill the decomposition
    nint = 1
    nbn = 1
    do ii = 1, size(tet_type)
       if ( tet_type(ii) .eq. 0 ) then
          inter_elems(nint) = ii 
          nint = nint + 1
       else
          near_bn_elems(nbn) = ii
          nbn = nbn + 1
       end if
    end do

    ! done here
  end subroutine decomp_based_on_bn

  !
  subroutine equal_decomp_nelem_by_np(nelem, np, arr)
    implicit none
    integer, intent(in) :: nelem, np
    integer, dimension(:), allocatable :: arr

    ! local vars
    integer :: i, Di

    Di = floor(dble(nelem) / dble(np))
    if ( allocated(arr) ) deallocate(arr)
    allocate(arr(np))

    arr = Di

    !almost equally add (distribute) the remainder
    do i = 1, mod(nelem, np)
       arr(i) = arr(i) + 1
    end do

    ! done here
  end subroutine equal_decomp_nelem_by_np

  ! 
  subroutine loc2glob_indx(arrl, arrg)
    implicit none
    integer, dimension(:), intent(in) :: arrl
    integer, dimension(:), allocatable :: arrg

    ! local vars
    integer :: i, tot_sum

    if ( allocated(arrg) ) deallocate(arrg)
    allocate(arrg(size(arrl) + 1))

    tot_sum = 1
    do i = 1, size(arrl)
       arrg(i) = tot_sum
       arrg(i+1) = tot_sum + arrl(i)  
       tot_sum  = tot_sum + arrl(i)
    end do

    ! done here
  end subroutine loc2glob_indx

end module curved_tet

program tester
  use curved_tet
  use mpi_comm_mod
  implicit none

  ! local vars
  integer :: nhole
  real*8, allocatable :: xh(:)
  type(mpi_comm_t) :: tmpi

  ! init MPI
  call tmpi%init()

  !
  ! call tester1()

  ! nhole = 1
  ! allocate(xh(3))
  ! xh = (/ 0.5714d0, 0.4333d0, 0.1180d0 /)

  ! call curved_tetgen_geom(tetgen_cmd = 'pq1.414nnY' &
  !      , facet_file = 'missile_spect3.facet' &
  !      , cad_file = 'store.iges', nhole = nhole, xh = xh, tol = .03d0, tmpi = tmpi)

  ! nhole = 1
  ! allocate(xh(3))
  ! xh = (/ 10.0d0, 0.0d0, 0.0d0 /)

  ! call curved_tetgen_geom(tetgen_cmd = 'pq1.214nnY' &
  !      , facet_file = 'civil3.facet' &
  !      , cad_file = 'civil3.iges', nhole = nhole, xh = xh, tol = 20.0d0, tmpi = tmpi)

  ! nhole = 1
  ! allocate(xh(3))
  ! xh = 0.0d0

  ! call curved_tetgen_geom(tetgen_cmd = 'pq1.414nnY' &
  !      , facet_file = 'pin.facet' &
  !      , cad_file = 'pin.iges', nhole = nhole, xh = xh, tol = .03d0)

  nhole = 1
  allocate(xh(3))
  xh = 0.0d0

  call curved_tetgen_geom(tetgen_cmd = 'pq1.414nnY' &
       , facet_file = 'sphere.facet' &
       , cad_file = 'sphere2.iges', nhole = nhole, xh = xh, tol = .03d0, tmpi = tmpi)



  print *, 'Done! The End!'

  call tmpi%finish()

  ! done here
end program tester
