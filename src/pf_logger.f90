module pf_mod_logger
  use pf_mod_dtype
  use pf_mod_hooks
  implicit none
contains

  subroutine pf_logger_hook(pf, level, state, ctx)
    type(pf_pfasst_t), intent(inout) :: pf
    type(pf_level_t),  intent(inout) :: level
    type(pf_state_t),  intent(in)    :: state
    type(c_ptr),       intent(in)    :: ctx

    print *, hook_names(state%hook), state%level
  end subroutine pf_logger_hook

  subroutine pf_logger_attach(pf)
    type(pf_pfasst_t), intent(inout) :: pf

    integer :: l, h

    do h = PF_HOOK_LOG_ONE, PF_HOOK_LOG_ALL-1
       call pf_add_hook(pf, 1, h, pf_logger_hook)
    end do

    do l = 1, pf%nlevels
       do h = PF_HOOK_LOG_ALL, PF_HOOK_LOG_LAST
          call pf_add_hook(pf, 1, h, pf_logger_hook)
       end do
    end do
  end subroutine pf_logger_attach

end module pf_mod_logger