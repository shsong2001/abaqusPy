c-----------------------------------------------------------------------
c     Dependents
c     hah_io in hah_lib.f
c     hah_decompose in hah_lib.f
c     yld in  ../yld.f
c-----------------------------------------------------------------------
      subroutine hah_yieldsurface(iyld_choice,yldc,nyldc,
     $     yldp,nyldp,cauchy,
     $     phi_chi,dphi_chi,d2phi_chi,ntens,
     $     phi_n,dphi_n,d2phi_n)
c     Arguments
c     iyld_choice: choice of yield surface kernel
c     yldc      : yield surface constants
c     nyldc     : Len of yldc
c     yldp      : yield surface parameters
c     nyldp     : Len of yldp
c     cauchy    : cauchy stress tensor
c     phi_chi   : isotropic yield surface
c     dphi_chi  : isotropic yield surface 1st derivative
c     d2phi_chi : isotropic yield surface 2nd derivative
c     ntens     : Len of cauchy stress tensor
c     phi_n     : HAH yield surface at step n
c     dphi_n    : HAH yield surface 1st derivative at step n
c     d2phi_n   : HAH yield surface 2nd derivative at step n
      implicit none
      integer iyld_choice,ntens,nyldp,nyldc
      dimension yldc(nyldc),yldp(nyldp),cauchy(ntens)

      real*8 yldc,yldp,cauchy

c     isotropic yield surface
      dimension dphi_chi(ntens),d2phi_chi(ntens,ntens)
      real*8, intent(in) :: phi_chi,dphi_chi,d2phi_chi

c     HAH yield surface
      dimension dphi_n(ntens),d2phi_n(ntens,ntens)
      real*8 phi_n,dphi_n,d2phi_n
      dimension phi_ns(0:1),dphi_ns(0:1,ntens),
     $     d2phi_ns(0:1,ntens,ntens)
      real*8 phi_ns,dphi_ns,d2phi_ns

c     local - microstructure deviator
      dimension emic(6)
      real*8 emic
c     local - Bauschinger parameters
      dimension gk(4)
      dimension e_ks(5)
      dimension f_ks(2)
      dimension target(ntens)
      real*8 gk,e_ks,f_ks,eeq,target
c     local - Latent hardening parameters
      real*8 gL,ekL,eL
c     local - cross hardening parameters
      real*8 gS,c_ks,ss
c     local
      dimension sc(ntens),so(ntens),sdp(ntens),sp(ntens) ! stress double prime
      real*8 sc,so,sdp,sp
c     local-latent
      dimension dphi_lat(ntens),d2phi_lat(ntens,ntens)
      real*8 phi_lat,dphi_lat,d2phi_lat
c     local-cross
      dimension dphi_x(ntens),d2phi_x(ntens,ntens),sdev(ntens)
      real*8 phi_x,dphi_x,d2phi_x,phi_omega,sdev
      integer imsg
cf2py intent(in) yldp,nylpd,cauchy,phi_chi,dphi_chi,d2phi_chi,ntens
cf2py intent(out) phi,dphi,d2phi

c-----------------------------------------------------------------------

      imsg = 0

      call fill_line(imsg,'#',72)
      call w_chr(imsg,'Enter HAH_YIELDSURFACE')
      call fill_line(imsg,'#',72)

c     obtain deviatoric stress
      call w_chr(imsg,'cauchy stress')
      call w_dim(imsg,cauchy,ntens,1d0,.false.)
      call deviat(cauchy,ntens,sdev)
      call w_chr(imsg,'deviatoric stress')
      call w_dim(imsg,sdev,ntens,1d0,.false.)

c      call exit(-1)


c-----------------------------------------------------------------------
      phi_ns(0)       = phi_n
      dphi_ns(0,:)    = dphi_n(:)
      d2phi_ns(0,:,:) = d2phi_n(:,:)

c     Restore yldp into state variables/parameters
      call hah_io(yldp,nyldp,eeq,ntens,emic,gk,e_ks,f_ks,gL,ekL,eL,gS,
     $     c_ks,ss,0)

c     calculate yield surface

c     decompose deviatoric stress
      call w_chr(imsg,'calling to hah_decompose')
      call hah_decompose(sdev,ntens,emic,sc,so)


      call w_chr(imsg,'sc')
      call w_dim(imsg,sc,ntens,1d0,.false.)
      call w_chr(imsg,'so')
      call w_dim(imsg,so,ntens,1d0,.false.)

      call w_chr(imsg,'deviatoric Stress decomposition')
      call w_dim(imsg,sdev,ntens,1d0,.false.)
c      call exit(-1)

c------------------------------
c     Latent extension
c------------------------------
c***  Target direction
      target(:) = sdev(:)
c***  stress double prime following eq 25 in Ref [1]
      if (gL.eq.0) then
         call w_empty_lines(imsg,2)
         call fill_line(imsg,'*',72)
         call w_chr(imsg,'**** Error gL is zero ****')
         call fill_line(imsg,'*',72)
         call exit(-1)
      endif
      sdp(:) = sc(:) + 1d0/gL
      call w_val(imsg,'gL:',gL)

      call w_chr(imsg,'deviatoric Stress decomposition')
      call w_dim(imsg,sdev,ntens,1d0,.false.)

      call w_chr(imsg,'sdp')
      call w_dim(imsg,sdp,ntens,1d0,.false.)
      call w_chr(imsg,'sc')
      call w_dim(imsg,sc,ntens,1d0,.false.)
c      call exit(-1)      

c------------------------------
c     Not sure if below would be okay since it seems like a recursive call
c     if that's the case, use yld2000_2d or vm_shell, hill48_shell directly
c------------------------------
      call w_chr(imsg,' ** calling yld for phi_lat **')
      call yld(iyld_choice,yldp,yldc,nyldp,nyldc,sdp,phi_lat,dphi_lat,
     $     d2phi_lat,ntens)
c      call exit(-1)

c------------------------------
c     Cross load hardening
c------------------------------
      sp(:) = 4d0*(1d0-gS)*so(:)
      call w_chr(imsg,' ** calling yld for phi_x **')
      call yld(iyld_choice,yldp,yldc,nyldp,nyldc,sp,phi_x,dphi_x,
     $     d2phi_x,ntens)

      phi_omega = (phi_chi**2+phi_x**2)**(0.5d0)

      call w_val(imsg,'phi_chi',phi_chi)
      call w_val(imsg,'phi_lat',phi_lat)
      call w_val(imsg,'phi_x',phi_x)
      call w_val(imsg,'phi_omega',phi_omega)
      call w_chr(imsg,'Exit HAH_YIELDSURFACE')

      call exit(-1)

      return
      end subroutine hah_yieldsurface
