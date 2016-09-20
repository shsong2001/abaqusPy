c-----------------------------------------------------------------------
c     Return mapping subroutine to find stress at n-1 step
c     and integrate all state variables during the given incremental
c     step defined by dstran (rate-independent ... yet?)
      subroutine return_mapping(Cel,spr,phi_n,eeq_n,dphi_n,voce_params,
     $     dstran,stran,stran_el,stran_pl,ntens,idiaw)
c     Arguments
c-----------------------------------------------------------------------
c     spr    : predictor stress at k=0
c     eeq_n  : accumulative plastic equivalent strain at step n
c     dphi_n : dphi at step n
c     voce_params (quite self-explanatory)
c     dstran : total incremental strain given between steps n and n+1
c     stran  : total cumulative strain at step n
c     stran_el: total elastic strain at step n
c     stran_pl: total plastic strain at step n
      implicit none
      character*255 fndia
      character*20 chr
      integer ntens,mxnr
      parameter(mxnr=10)
c-----------------------------------------------------------------------
      dimension spr(ntens),dphi_n(ntens),sn1(ntens),s_k(ntens),
     $     spr_ks(mxnr,ntens),dstran(ntens),stran(ntens),
     $     stran_el(ntens),
     $     dstran_el(ntens),dstran_el_k(ntens),stran_el_ks(mxnr,ntens),
     $     stran_pl(ntens),
     $     dstran_pl(ntens),dstran_pl_k(ntens),stran_pl_ks(mxnr,ntens),
     $     aux_n(ntens),em_k(ntens),Cel(ntens,ntens),eeq_ks(mxnr),
     $     enorm_k(mxnr,ntens),fo_ks(mxnr),fp_ks(mxnr),dlamb_ks(mxnr),
     $     dphi_ks(mxnr,ntens),d2phi_ks(mxnr,ntens,ntens),phi_ks(mxnr),
     $     voce_params(4),dh_ks(mxnr)
c-----------------------------------------------------------------------

      real*8 Cel,spr,dphi_n,
     $     dstran,stran,
     $     stran_el,dstran_el,dstran_el_k,stran_el_k,stran_el_ks,
     $     stran_pl,dstran_pl,dstran_pl_k,stran_pl_k,stran_pl_ks
      real*8 sn1                ! stress at step (n+1) - to be determined
      real*8 s_k,seq_k,spr_ks   ! eq stress at nr-step k, stress predic at nr-step k
      real*8 enorm_k            ! m_(n+alpha)
      real*8 fo_ks,fp_ks        ! Fobjective, Jacobian for NR
      real*8 dlamb_k,dlamb_ks,phi_n
      real*8 dphi_ks,d2phi_ks
      real*8 delta_eeq,eeq_n,aux_n,eeq_k,eeq_ks,empa,gpa
      real*8 voce_params,h_flow,dh_ks,phi_k,phi_ks,em_k,tolerance
      integer k,idia,imsg
      parameter(tolerance=1d-10)
      logical idiaw,ibreak


      write(*,*)'ntens:',ntens
      if (ntens.ne.3) then
         write(*,*)'Err: unexpected dimension of tensor given',ntens
         stop
      endif

      empa=1d6
      gpa =1d9

      delta_eeq = 0d0 ! initial guess on equivalent strain rate contribution to dstran
      dlamb_ks(1) = delta_eeq
      spr_ks(1,:) = spr(:)       !! stress predictor
      enorm_k(1,:) = dphi_n(:)
      phi_ks(1) = phi_n

c------------------------------------------------------------------------
c     iv. return mapping (loop over k)
      k=1

      idia=315
      imsg=7

      if (idiaw) then
c$$$         fndia='/home/younguj/repo/abaqusPy/examples/one/diagnose.txt'
c$$$         open(idia,position='append',file=fndia)
 3       call w_empty_lines(idia,3)
         write(idia,*)'Enter NR--'
         write(*,*)'Enter NR--'
      endif

      ibreak=.false.
      do while (.not.(ibreak))

         s_k(:) = spr_ks(k,:)    ! predictor stress at current k
         em_k(:) = enorm_k(k,:) ! yield normal at current k
         eeq_ks(k) = eeq_n + delta_eeq ! assumed plastic strain at current k
         eeq_k = eeq_ks(k)
         phi_k = phi_ks(k)

         if (idiaw) then
            write(*,*) 'i-NR: ', k

            write(*,*)'S_k'
            call w_dim(0,s_k,ntens,1d0/empa,.true.)
            write(*,*)'m_k'
            call w_dim(0,em_k,ntens,1d0,.true.)
            call w_val(0,'delta_eeq   :',delta_eeq)
            call w_val(0,'eeq_k       :',eeq_k)
            call w_val(0,'phi_n [MPa] :',phi_k/empa)
         endif
c-----------------------------------------------------------------------



c        f   = yield - hardening             (objective function)
         fo_ks(k) = phi_ks(k) - h_flow


         if (fo_ks(k).le.tolerance)then
            ibreak=.true.
         else
c           Find Fp
c           ** Use values pertaining to n+1 step (assuming that current eeq_ks(k) is correct)
            call voce(eeq_ks(k),voce_params(1),voce_params(2),
     $           voce_params(3),voce_params(1),h_flow,dh_ks(k))
c           unit correction
            h_flow    = h_flow   * empa
            dh_ks(k)  = dh_ks(k) * empa
            call vm_shell(spr_ks(k,:),phi_ks(k),dphi_ks(k,:),
     $           d2phi_ks(k,:,:))
            call calc_fp(dphi_ks(k,:),Cel,dh_ks(k),ntens,fp_ks(k))
         endif

         if (idiaw) then
            call w_val(0,'h_flow [MPa]:',h_flow/empa)
            call w_val(0,'dh(k+1)[MPa]:',dh_ks(k+1)/empa)
            call w_val(0,'fo_ks(k)[MPa]:',fo_ks(k)/empa)
            call w_val(0,'fp_ks(k)[GPa]:',fp_ks(k)/gpa)
         endif

c------------------------------------------------------------------------
c         2.  Update the multiplier^(k+1)  (dlamb)
c             dlamb^(k+1) = dlamb^k - fo_ks(k)/fp_ks(k)
         dlamb_ks(k+1) = dlamb_ks(k) - fo_ks(k)/fp_ks(k)
         call w_val(0,'dlamb_ks(k+1)',dlamb_ks(k+1))
         stop
c             find the new predictor stress for next NR step
c                Using  dE = dE^(el)^(k+1) + dlamb^(k+1),
c                Update dE^(el)^(k+1) and update the predictor stress.
         dstran_el(:) = dstran(:) - dlamb_k
         call add_array(stran_el_k,dstran_el,ntens)
c             s_(n+1)^(k+1) = C^e dE^(el)
         call mult_array(cel,stran_el_k,aux_n)
         spr_ks(k+1,:) = aux_n(:)

         if (idiaw) then
            call w_dim(idia,dstran,ntens,1d0,.false.)
            call w_dim(idia,s_k,ntens,1d0/empa,.false.)
            write(idia,'(x,a1,x)',advance='no') '|'
         endif

c------------------------------------------------------------------------
c        3. Find normal of current predictor stress (s_(n+1)^k)
c             save the normal to m_(n+alpha)
         call vm_shell(spr_ks(k+1,:),enorm_k(k+1,:),dphi_ks(k+1,:),
     $        d2phi_ks(k+1,:,:))
         k=k+1
         if (k.ge.mxnr) then
            write(*,*) 'Could not converge in NR scheme'
            stop
         endif
      enddo



c      if (idiaw) close(idia)
      return
      end subroutine

c-----------------------------------------------------------------------
c     Calculate fp using the below formula
c     fp  = r(s^eq_(n+1)^k)/r(s_(n+1)^k) : -C^el : r(s^eq_(n+1)^k / r(s_(n+1)^k) + H`)
c     fp = dphi_i C_ij dphi_j + H
      subroutine calc_fp(dphi,Cel,dh,ntens,fp)
c     intent(in) dphi,Cel,dh,ntens
c     intent(out) fp
      implicit none
      integer ntens
      dimension s(ntens),Cel(ntens,ntens),dphi(ntens)
      real*8 s,seq,Cel,dphi,fp,dh
      integer i,j
      fp=0.d0
      do 10 i=1,ntens
      do 10 j=1,ntens
         fp=fp+dphi(i) * Cel(i,j) * dphi(j) +dh
 10   continue
      return
      end subroutine
