save_file_set_flags(SAVE_FLAG_FILE_EXISTS)
save_file_set_flags(SAVE_FLAG_COLLECTED_MIPS_STAR_1)
save_file_set_flags(SAVE_FLAG_COLLECTED_MIPS_STAR_2)
save_file_set_flags(SAVE_FLAG_COLLECTED_TOAD_STAR_1)
save_file_set_flags(SAVE_FLAG_COLLECTED_TOAD_STAR_2)
save_file_set_flags(SAVE_FLAG_COLLECTED_TOAD_STAR_3)
save_file_set_flags(SAVE_FLAG_DDD_MOVED_BACK)
save_file_set_flags(SAVE_FLAG_HAVE_METAL_CAP)
save_file_set_flags(SAVE_FLAG_HAVE_VANISH_CAP)
save_file_set_flags(SAVE_FLAG_HAVE_WING_CAP)
save_file_set_flags(SAVE_FLAG_MOAT_DRAINED)
save_file_set_flags(SAVE_FLAG_UNLOCKED_50_STAR_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_BASEMENT_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_BITDW_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_BITFS_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_CCM_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_JRB_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_PSS_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)
save_file_set_flags(SAVE_FLAG_UNLOCKED_WF_DOOR)

local file = get_current_save_file_num() - 1
for i = COURSE_BOB - 1, COURSE_RR - 1, 1 do
    save_file_set_star_flags(file, i, 255)
end
save_file_set_star_flags(file, COURSE_NONE - 1, 31)

save_file_set_star_flags(file, COURSE_SA - 1, 1)
save_file_set_star_flags(file, COURSE_PSS - 1, 3)
save_file_set_star_flags(file, COURSE_WMOTR - 1, 1)

save_file_set_star_flags(file, COURSE_BITDW - 1, 1)
save_file_set_star_flags(file, COURSE_BITFS - 1, 1)
save_file_set_star_flags(file, COURSE_BITS - 1, 1)

save_file_set_star_flags(file, COURSE_TOTWC - 1, 1)
save_file_set_star_flags(file, COURSE_VCUTM - 1, 1)
save_file_set_star_flags(file, COURSE_COTMC - 1, 1)