-- ============================================================================
-- NoVi database handoff - final MySQL 8.0 schema
-- Target database: novi_test
--
-- This is a one-time bootstrap file. It combines novi_schema_v1.sql with:
--   002_publishing.sql, 003_personal_reading.sql, 004_read_rankings.sql.
-- It intentionally contains no real account, password, token, connection
-- string, reading history, view count or other user data.
--
-- SAFETY: the script aborts when novi_test already contains any base table.
-- It never drops a database or an existing application table.
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS `novi_test`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE `novi_test`;

DELIMITER $$
CREATE PROCEDURE `_novi_assert_empty_database`()
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND table_type = 'BASE TABLE'
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'NoVi import stopped: target database already contains tables.';
  END IF;
END$$
DELIMITER ;

CALL `_novi_assert_empty_database`();
DROP PROCEDURE `_novi_assert_empty_database`;

CREATE TABLE `user` (
  `user_id` CHAR(36) NOT NULL,
  `full_name` VARCHAR(100) NOT NULL,
  `display_name` VARCHAR(100) NULL,
  `avatar_url` VARCHAR(500) NULL,
  `username` VARCHAR(100) NULL,
  `email` VARCHAR(191) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` TINYINT NOT NULL DEFAULT 0 COMMENT '0 reader, 1 author/translator, 2 admin',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '0 locked, 1 active',
  `lock_reason` VARCHAR(500) NULL,
  `locked_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uq_user_email` (`email`),
  UNIQUE KEY `uq_user_username` (`username`),
  KEY `idx_user_role_status` (`role`, `status`),
  CONSTRAINT `ck_user_role` CHECK (`role` BETWEEN 0 AND 2),
  CONSTRAINT `ck_user_status` CHECK (`status` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `password_reset` (
  `reset_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NOT NULL,
  `otp_hash` VARCHAR(255) NOT NULL,
  `expires_at` DATETIME NOT NULL,
  `used_at` DATETIME NULL,
  `attempt_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reset_id`),
  KEY `idx_password_reset_lookup` (`user_id`, `expires_at`, `used_at`),
  CONSTRAINT `fk_password_reset_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `category` (
  `category_id` CHAR(36) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `slug` VARCHAR(120) NOT NULL,
  `is_active` TINYINT NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`category_id`),
  UNIQUE KEY `uq_category_name` (`name`),
  UNIQUE KEY `uq_category_slug` (`slug`),
  KEY `idx_category_active` (`is_active`),
  CONSTRAINT `ck_category_active` CHECK (`is_active` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `author_application` (
  `application_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NOT NULL,
  `message` VARCHAR(1000) NULL,
  `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0 pending, 1 approved, 2 rejected',
  `decision_reason` VARCHAR(1000) NULL,
  `reviewed_by` CHAR(36) NULL,
  `reviewed_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pending_flag` TINYINT GENERATED ALWAYS AS (IF(`status` = 0, 1, NULL)) STORED,
  PRIMARY KEY (`application_id`),
  UNIQUE KEY `uq_author_application_pending` (`user_id`, `pending_flag`),
  KEY `idx_author_application_queue` (`status`, `created_at`),
  CONSTRAINT `fk_author_application_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_author_application_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_author_application_status` CHECK (`status` BETWEEN 0 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `moderation_decision` (
  `decision_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `target_type` TINYINT NOT NULL COMMENT '1 novel, 2 chapter, 3 novel revision, 4 chapter revision, 5 author application',
  `target_id` CHAR(36) NOT NULL,
  `decision` TINYINT NOT NULL COMMENT '1 approved, 2 rejected',
  `reason` VARCHAR(1000) NULL,
  `reviewed_by` CHAR(36) NOT NULL,
  `reviewed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`decision_id`),
  KEY `idx_moderation_target` (`target_type`, `target_id`, `reviewed_at`),
  KEY `idx_moderation_reviewer` (`reviewed_by`, `reviewed_at`),
  CONSTRAINT `fk_moderation_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `user` (`user_id`),
  CONSTRAINT `ck_moderation_target_type` CHECK (`target_type` BETWEEN 1 AND 5),
  CONSTRAINT `ck_moderation_decision` CHECK (`decision` IN (1, 2))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `novel` (
  `novel_id` CHAR(36) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `slug` VARCHAR(280) NOT NULL,
  `original_author` VARCHAR(255) NULL,
  `uploader_id` CHAR(36) NOT NULL,
  `source_type` TINYINT NOT NULL DEFAULT 0 COMMENT '0 original, 1 translation',
  `source_url` VARCHAR(1000) NULL,
  `description` TEXT NULL,
  `cover_url` VARCHAR(500) NULL,
  `completion_status` TINYINT NOT NULL DEFAULT 0 COMMENT '0 ongoing, 1 completed, 2 paused',
  `review_status` TINYINT NOT NULL DEFAULT 0 COMMENT '0 pending, 1 approved, 2 rejected',
  `visibility` TINYINT NOT NULL DEFAULT 0 COMMENT '0 visible, 1 hidden by owner, 2 removed by admin',
  `reject_reason` VARCHAR(1000) NULL,
  `reviewed_by` CHAR(36) NULL,
  `reviewed_at` DATETIME NULL,
  `published_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`novel_id`),
  UNIQUE KEY `uq_novel_slug` (`slug`),
  KEY `idx_novel_discover` (`review_status`, `visibility`, `deleted_at`, `updated_at`),
  KEY `idx_novel_uploader` (`uploader_id`, `deleted_at`, `updated_at`),
  KEY `idx_novel_title` (`title`),
  FULLTEXT KEY `ft_novel_search` (`title`, `original_author`, `description`),
  CONSTRAINT `fk_novel_uploader` FOREIGN KEY (`uploader_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `fk_novel_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_novel_source_type` CHECK (`source_type` IN (0, 1)),
  CONSTRAINT `ck_novel_completion` CHECK (`completion_status` BETWEEN 0 AND 2),
  CONSTRAINT `ck_novel_review` CHECK (`review_status` BETWEEN 0 AND 2),
  CONSTRAINT `ck_novel_visibility` CHECK (`visibility` BETWEEN 0 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `novel_category` (
  `novel_id` CHAR(36) NOT NULL,
  `category_id` CHAR(36) NOT NULL,
  PRIMARY KEY (`novel_id`, `category_id`),
  KEY `idx_novel_category_category` (`category_id`, `novel_id`),
  CONSTRAINT `fk_novel_category_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_novel_category_category` FOREIGN KEY (`category_id`) REFERENCES `category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chapter` (
  `chapter_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `chapter_number` INT UNSIGNED NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `content` MEDIUMTEXT NOT NULL,
  `review_status` TINYINT NOT NULL DEFAULT 0,
  `visibility` TINYINT NOT NULL DEFAULT 0,
  `reject_reason` VARCHAR(1000) NULL,
  `reviewed_by` CHAR(36) NULL,
  `reviewed_at` DATETIME NULL,
  `published_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  `active_flag` TINYINT GENERATED ALWAYS AS (IF(`deleted_at` IS NULL, 1, NULL)) STORED,
  PRIMARY KEY (`chapter_id`),
  UNIQUE KEY `uq_chapter_number` (`novel_id`, `chapter_number`, `active_flag`),
  UNIQUE KEY `uq_chapter_novel_id` (`novel_id`, `chapter_id`),
  KEY `idx_chapter_public_list` (`novel_id`, `review_status`, `visibility`, `deleted_at`, `chapter_number`),
  KEY `idx_chapter_reviewer` (`reviewed_by`),
  CONSTRAINT `fk_chapter_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`),
  CONSTRAINT `fk_chapter_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_chapter_number` CHECK (`chapter_number` > 0),
  CONSTRAINT `ck_chapter_review` CHECK (`review_status` BETWEEN 0 AND 2),
  CONSTRAINT `ck_chapter_visibility` CHECK (`visibility` BETWEEN 0 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `novel_revision` (
  `revision_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `submitted_by` CHAR(36) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `original_author` VARCHAR(255) NULL,
  `source_type` TINYINT NOT NULL DEFAULT 0,
  `source_url` VARCHAR(1000) NULL,
  `description` TEXT NULL,
  `cover_url` VARCHAR(500) NULL,
  `completion_status` TINYINT NOT NULL DEFAULT 0,
  `review_status` TINYINT NOT NULL DEFAULT 0,
  `reject_reason` VARCHAR(1000) NULL,
  `reviewed_by` CHAR(36) NULL,
  `reviewed_at` DATETIME NULL,
  `submitted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pending_flag` TINYINT GENERATED ALWAYS AS (IF(`review_status` = 0, 1, NULL)) STORED,
  PRIMARY KEY (`revision_id`),
  UNIQUE KEY `uq_novel_revision_pending` (`novel_id`, `pending_flag`),
  KEY `idx_novel_revision_queue` (`review_status`, `submitted_at`),
  CONSTRAINT `fk_novel_revision_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_novel_revision_submitter` FOREIGN KEY (`submitted_by`) REFERENCES `user` (`user_id`),
  CONSTRAINT `fk_novel_revision_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_novel_revision_review` CHECK (`review_status` BETWEEN 0 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chapter_revision` (
  `revision_id` CHAR(36) NOT NULL,
  `chapter_id` CHAR(36) NOT NULL,
  `submitted_by` CHAR(36) NOT NULL,
  `title` VARCHAR(255) NOT NULL,
  `content` MEDIUMTEXT NOT NULL,
  `review_status` TINYINT NOT NULL DEFAULT 0,
  `reject_reason` VARCHAR(1000) NULL,
  `reviewed_by` CHAR(36) NULL,
  `reviewed_at` DATETIME NULL,
  `submitted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pending_flag` TINYINT GENERATED ALWAYS AS (IF(`review_status` = 0, 1, NULL)) STORED,
  PRIMARY KEY (`revision_id`),
  UNIQUE KEY `uq_chapter_revision_pending` (`chapter_id`, `pending_flag`),
  KEY `idx_chapter_revision_queue` (`review_status`, `submitted_at`),
  CONSTRAINT `fk_chapter_revision_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapter` (`chapter_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chapter_revision_submitter` FOREIGN KEY (`submitted_by`) REFERENCES `user` (`user_id`),
  CONSTRAINT `fk_chapter_revision_reviewer` FOREIGN KEY (`reviewed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_chapter_revision_review` CHECK (`review_status` BETWEEN 0 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `library_item` (
  `user_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `novel_id`),
  KEY `idx_library_recent` (`user_id`, `created_at`),
  KEY `idx_library_interest` (`novel_id`, `created_at`),
  CONSTRAINT `fk_library_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_library_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reading_session` (
  `session_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `started_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`session_id`),
  KEY `idx_reading_session_owner` (`user_id`, `novel_id`, `started_at`),
  CONSTRAINT `fk_reading_session_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_session_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reading_progress` (
  `user_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `chapter_id` CHAR(36) NOT NULL,
  `position_percent` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  `session_id` CHAR(36) NULL,
  `session_started_at` DATETIME(6) NULL,
  `client_sequence` BIGINT NOT NULL DEFAULT 0,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `novel_id`),
  KEY `idx_reading_progress_recent` (`user_id`, `updated_at`),
  KEY `idx_reading_progress_chapter` (`novel_id`, `chapter_id`),
  KEY `idx_reading_progress_session` (`session_id`),
  CONSTRAINT `fk_reading_progress_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_progress_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_progress_chapter` FOREIGN KEY (`novel_id`, `chapter_id`) REFERENCES `chapter` (`novel_id`, `chapter_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_progress_session` FOREIGN KEY (`session_id`) REFERENCES `reading_session` (`session_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_reading_progress_position` CHECK (`position_percent` BETWEEN 0 AND 100),
  CONSTRAINT `ck_reading_progress_sequence` CHECK (`client_sequence` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `reading_history` (
  `history_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` CHAR(36) NOT NULL,
  `chapter_id` CHAR(36) NOT NULL,
  `read_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`history_id`),
  KEY `idx_reading_history_user` (`user_id`, `read_at`),
  KEY `idx_reading_history_chapter` (`chapter_id`, `read_at`),
  CONSTRAINT `fk_reading_history_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_history_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapter` (`chapter_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `chapter_view` (
  `view_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `chapter_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NULL,
  `viewer_key_hash` CHAR(64) NULL COMMENT 'privacy-preserving key for future anonymous-view deduplication',
  `viewed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `view_window` BIGINT NULL COMMENT 'fixed time bucket used for authenticated-view deduplication',
  PRIMARY KEY (`view_id`),
  UNIQUE KEY `uq_chapter_view_user_window` (`chapter_id`, `user_id`, `view_window`),
  KEY `idx_chapter_view_statistics` (`chapter_id`, `viewed_at`),
  KEY `idx_chapter_view_user` (`user_id`, `viewed_at`),
  KEY `idx_chapter_view_period` (`viewed_at`, `chapter_id`),
  CONSTRAINT `fk_chapter_view_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapter` (`chapter_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chapter_view_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `donation` (
  `donation_id` CHAR(36) NOT NULL,
  `donor_id` CHAR(36) NOT NULL,
  `recipient_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NULL,
  `amount` DECIMAL(15,2) NOT NULL,
  `currency` CHAR(3) NOT NULL DEFAULT 'VND',
  `message` VARCHAR(500) NULL,
  `gateway` VARCHAR(30) NOT NULL,
  `order_code` VARCHAR(100) NOT NULL,
  `gateway_transaction_id` VARCHAR(191) NULL,
  `status` TINYINT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` DATETIME NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`donation_id`),
  UNIQUE KEY `uq_donation_order_code` (`order_code`),
  UNIQUE KEY `uq_donation_gateway_transaction` (`gateway`, `gateway_transaction_id`),
  KEY `idx_donation_donor` (`donor_id`, `created_at`),
  KEY `idx_donation_recipient` (`recipient_id`, `status`, `created_at`),
  KEY `idx_donation_novel` (`novel_id`, `status`, `created_at`),
  CONSTRAINT `fk_donation_donor` FOREIGN KEY (`donor_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `fk_donation_recipient` FOREIGN KEY (`recipient_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `fk_donation_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_donation_amount` CHECK (`amount` > 0),
  CONSTRAINT `ck_donation_not_self` CHECK (`donor_id` <> `recipient_id`),
  CONSTRAINT `ck_donation_status` CHECK (`status` BETWEEN 0 AND 4)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `donation_event` (
  `event_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `donation_id` CHAR(36) NOT NULL,
  `event_type` VARCHAR(50) NOT NULL,
  `gateway_event_id` VARCHAR(191) NULL,
  `status_before` TINYINT NULL,
  `status_after` TINYINT NOT NULL,
  `payload_hash` CHAR(64) NULL,
  `received_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`event_id`),
  UNIQUE KEY `uq_donation_gateway_event` (`gateway_event_id`),
  KEY `idx_donation_event_history` (`donation_id`, `received_at`),
  CONSTRAINT `fk_donation_event_donation` FOREIGN KEY (`donation_id`) REFERENCES `donation` (`donation_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `content_report` (
  `report_id` CHAR(36) NOT NULL,
  `reporter_id` CHAR(36) NOT NULL,
  `target_type` TINYINT NOT NULL COMMENT '1 novel, 2 chapter',
  `target_id` CHAR(36) NOT NULL,
  `reason` TINYINT NOT NULL,
  `description` VARCHAR(1000) NULL,
  `status` TINYINT NOT NULL DEFAULT 0,
  `resolution_note` VARCHAR(1000) NULL,
  `handled_by` CHAR(36) NULL,
  `handled_at` DATETIME NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pending_flag` TINYINT GENERATED ALWAYS AS (IF(`status` = 0, 1, NULL)) STORED,
  PRIMARY KEY (`report_id`),
  UNIQUE KEY `uq_content_report_pending` (`reporter_id`, `target_type`, `target_id`, `pending_flag`),
  KEY `idx_content_report_queue` (`status`, `created_at`),
  KEY `idx_content_report_target` (`target_type`, `target_id`),
  CONSTRAINT `fk_content_report_reporter` FOREIGN KEY (`reporter_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `fk_content_report_handler` FOREIGN KEY (`handled_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_content_report_target` CHECK (`target_type` IN (1, 2)),
  CONSTRAINT `ck_content_report_status` CHECK (`status` BETWEEN 0 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `similarity_check` (
  `check_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `checked_by` CHAR(36) NOT NULL,
  `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0 pending, 1 processing, 2 completed, 3 failed',
  `overall_percent` DECIMAL(5,2) NULL,
  `error_message` VARCHAR(1000) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` DATETIME NULL,
  PRIMARY KEY (`check_id`),
  KEY `idx_similarity_check_novel` (`novel_id`, `created_at`),
  KEY `idx_similarity_check_queue` (`status`, `created_at`),
  CONSTRAINT `fk_similarity_check_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_similarity_check_user` FOREIGN KEY (`checked_by`) REFERENCES `user` (`user_id`),
  CONSTRAINT `ck_similarity_check_status` CHECK (`status` BETWEEN 0 AND 3),
  CONSTRAINT `ck_similarity_check_percent` CHECK (`overall_percent` IS NULL OR `overall_percent` BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `similarity_match` (
  `match_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `check_id` CHAR(36) NOT NULL,
  `chapter_id` CHAR(36) NOT NULL,
  `matched_chapter_id` CHAR(36) NULL,
  `similarity_percent` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`match_id`),
  KEY `idx_similarity_match_check` (`check_id`, `similarity_percent`),
  KEY `idx_similarity_match_chapter` (`chapter_id`),
  KEY `idx_similarity_match_target` (`matched_chapter_id`),
  CONSTRAINT `fk_similarity_match_check` FOREIGN KEY (`check_id`) REFERENCES `similarity_check` (`check_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_similarity_match_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapter` (`chapter_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_similarity_match_target` FOREIGN KEY (`matched_chapter_id`) REFERENCES `chapter` (`chapter_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_similarity_match_percent` CHECK (`similarity_percent` BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MySQL 8.0.41 does not permit a CHECK on matched_chapter_id while the same
-- column is used by an ON DELETE SET NULL foreign key. The application must
-- reject self-matches when writing similarity results.

-- --------------------------------------------------------------------------
-- Safe handoff demo data: 14 novels, 28 original demo chapters
-- Cover files must accompany the backend under wwwroot/uploads/test/demo-covers.
-- The synthetic owner is locked and cannot authenticate.
-- No personal library/history/view/token/OTP data is included.
-- --------------------------------------------------------------------------

INSERT INTO `user` VALUES ('90000000-0000-0000-0000-000000000001','NoVi Demo','NoVi Demo',NULL,NULL,'novi-demo-owner@invalid.local','NO_LOGIN_DISABLED_DEMO_OWNER',1,0,'Synthetic locked owner for handoff demo content','2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 13:09:15');
INSERT INTO `category` VALUES ('92000000-0000-0000-0000-000000000001','Ngôn tình','ngon-tinh',1,'2026-11-16 13:09:15','2026-11-16 13:09:15'),('92000000-0000-0000-0000-000000000002','Hồi ký','hoi-ky',1,'2026-11-16 13:09:15','2026-11-16 13:09:15'),('92000000-0000-0000-0000-000000000003','Tản văn','tan-van',1,'2026-11-16 13:09:15','2026-11-16 13:09:15'),('92000000-0000-0000-0000-000000000004','Thiếu nhi','thieu-nhi',1,'2026-11-16 13:09:15','2026-11-16 13:09:15'),('92000000-0000-0000-0000-000000000005','Chưa phân loại','chua-phan-loai',1,'2026-11-16 13:09:15','2026-11-16 13:09:15');
INSERT INTO `novel` VALUES ('91000000-0000-0000-0000-000000000001','Bên Nhau Trọn Đời','novi-demo-ben-nhau-tron-doi',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi dùng bìa Bên Nhau Trọn Đời để kiểm thử trình đọc; dự án chưa bổ sung tác giả hoặc tóm tắt cốt truyện đã xác minh.','/uploads/test/demo-covers/ben-nhau-tron-doi.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000002','Chiếc Bật Lửa Và Váy Công Chúa','novi-demo-chiec-bat-lua-va-vay-cong-chua',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi dùng bìa Chiếc Bật Lửa Và Váy Công Chúa cho dữ liệu demo; không đại diện nội dung xuất bản và chưa xác nhận thông tin tác giả.','/uploads/test/demo-covers/chiec-bat-lua-va-vay-cong-chua.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000003','Khó Dỗ Dành','novi-demo-kho-do-danh',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Khó Dỗ Dành chỉ phục vụ thử giao diện, tìm kiếm và chuyển chương; chưa cung cấp phần giới thiệu chính thức.','/uploads/test/demo-covers/kho-do-danh.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000004','Miển Thư','novi-demo-mien-thu',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Miển Thư giữ đúng tên đọc trên bìa; thể loại, tác giả và cốt truyện vẫn cần nguồn thông tin bổ sung.','/uploads/test/demo-covers/mien-thu.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000005','Một Lít Nước Mắt','novi-demo-mot-lit-nuoc-mat',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Một Lít Nước Mắt dùng để kiểm tra hiển thị bìa và chương demo; phần văn bản bên dưới hoàn toàn do dự án tự viết.','/uploads/test/demo-covers/mot-lit-nuoc-mat.jpg',1,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000006','Nhật Thực Toàn Phần','novi-demo-nhat-thuc-toan-phan',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Nhật Thực Toàn Phần chưa có metadata cốt truyện đã xác minh; các chương chỉ mô phỏng trải nghiệm đọc.','/uploads/test/demo-covers/nhat-thuc-toan-phan.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000007','Nếu Biết Trăm Năm Là Hữu Hạn','novi-demo-neu-biet-tram-nam-la-huu-han',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Nếu Biết Trăm Năm Là Hữu Hạn phục vụ kiểm thử ứng dụng; không trích dẫn hoặc tóm lược văn bản của sách.','/uploads/test/demo-covers/neu-biet-tram-nam-la-huu-han.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000008','Trên Đồi, Mở Mắt Và Mơ','novi-demo-tren-doi-mo-mat-va-mo',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Trên Đồi, Mở Mắt Và Mơ dùng bìa đã cung cấp; các cảnh trong chương demo không phải tình tiết của tác phẩm.','/uploads/test/demo-covers/tren-doi-mo-mat-va-mo.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000009','Trốn Lên Mái Nhà Để Khóc','novi-demo-tron-len-mai-nha-de-khoc',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Trốn Lên Mái Nhà Để Khóc chỉ dùng cho môi trường thử nghiệm; dự án chưa xác nhận tác giả và nội dung chính thức.','/uploads/test/demo-covers/tron-len-mai-nha-de-khoc.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000010','Tìm Đến Chốn Bình Yên','novi-demo-tim-den-chon-binh-yen',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Tìm Đến Chốn Bình Yên dùng để thử tủ sách và lịch sử đọc; không khẳng định bất kỳ cốt truyện gốc nào.','/uploads/test/demo-covers/tim-den-chon-binh-yen.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000011','Tăng Hạ','novi-demo-tang-ha',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Tăng Hạ giữ trạng thái Chưa phân loại vì bìa chưa đủ căn cứ; chương demo không mô tả tác phẩm thật.','/uploads/test/demo-covers/tang-ha.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000012','Xuân Khởi','novi-demo-xuan-khoi',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Xuân Khởi phục vụ thử bố cục và tiến độ đọc; thông tin tác giả và giới thiệu chính thức chưa được cung cấp.','/uploads/test/demo-covers/xuan-khoi.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000013','Đám Trẻ Ở Đại Dương Đen','novi-demo-dam-tre-o-dai-duong-den',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Đám Trẻ Ở Đại Dương Đen dùng cho trình đọc demo; văn bản không sao chép hay diễn giải nội dung sách.','/uploads/test/demo-covers/dam-tre-o-dai-duong-den.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('91000000-0000-0000-0000-000000000014','Đốt Cháy','novi-demo-dot-chay',NULL,'90000000-0000-0000-0000-000000000001',0,NULL,'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm. Bản ghi Đốt Cháy phục vụ kiểm thử NoVi; các chương minh họa là văn bản độc lập do dự án tạo.','/uploads/test/demo-covers/dot-chay.jpg',0,1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL);
INSERT INTO `novel_category` VALUES ('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001'),('91000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001'),('91000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001'),('91000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000005'),('91000000-0000-0000-0000-000000000005','92000000-0000-0000-0000-000000000002'),('91000000-0000-0000-0000-000000000006','92000000-0000-0000-0000-000000000005'),('91000000-0000-0000-0000-000000000007','92000000-0000-0000-0000-000000000003'),('91000000-0000-0000-0000-000000000008','92000000-0000-0000-0000-000000000004'),('91000000-0000-0000-0000-000000000009','92000000-0000-0000-0000-000000000005'),('91000000-0000-0000-0000-000000000010','92000000-0000-0000-0000-000000000005'),('91000000-0000-0000-0000-000000000011','92000000-0000-0000-0000-000000000005'),('91000000-0000-0000-0000-000000000012','92000000-0000-0000-0000-000000000001'),('91000000-0000-0000-0000-000000000013','92000000-0000-0000-0000-000000000005'),('91000000-0000-0000-0000-000000000014','92000000-0000-0000-0000-000000000001');
INSERT INTO `chapter` (`chapter_id`, `novel_id`, `chapter_number`, `title`, `content`, `review_status`, `visibility`, `reject_reason`, `reviewed_by`, `reviewed_at`, `published_at`, `created_at`, `updated_at`, `deleted_at`) VALUES ('93000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001',1,'Khoảng cách trên trang giấy','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột giao lộ được vẽ bằng vài nét chì, hai dấu chấm đứng ở hai phía và khoảng trống ở giữa dành cho người đọc tưởng tượng. Khi cuộn xuống, những mảng màu đổi chậm từ vàng sang xanh, đủ dài để thử lưu vị trí mà không kể câu chuyện của tác phẩm.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 13:09:15',NULL),('93000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000001',2,'Dấu trang cuối buổi','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nBuổi đọc thử khép lại bằng một chiếc lá giấy đặt cạnh lề. Người đọc có thể đổi cỡ chữ, quay lại đoạn trước rồi đóng màn hình; dấu trang điện tử cần đưa họ trở về đúng nơi này.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 13:09:15',NULL),('93000000-0000-0000-0000-000000000003','91000000-0000-0000-0000-000000000002',1,'Hai vật thể trong khung hình','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nTrang minh họa đặt một nguồn sáng nhỏ cạnh dải màu hồng, dùng tương phản để kiểm tra nền sáng và nền tối. Không nhân vật hay tình tiết nào của sách được tái hiện trong đoạn thử này.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 13:09:15',NULL),('93000000-0000-0000-0000-000000000004','91000000-0000-0000-0000-000000000002',2,'Ánh sáng chuyển màu','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nCác câu ngắn dần nhường chỗ cho một đoạn dài hơn, giúp kiểm tra xuống dòng trên màn hình hẹp. Ở cuối trang, ánh sáng chỉ còn là một chấm màu và nút chuyển chương trở thành điểm tương tác tiếp theo.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 13:09:15',NULL),('93000000-0000-0000-0000-000000000005','91000000-0000-0000-0000-000000000003',1,'Trạm chờ buổi sớm','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột trạm chờ tưởng tượng hiện ra trong bản demo, với ghế gỗ, bóng cây và bảng giờ không ghi địa danh. Cảnh trung tính này chỉ giúp người dùng thử cuộn, chọn nền đọc và đánh dấu tiến độ.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000006','91000000-0000-0000-0000-000000000003',2,'Lời nhắn chưa gửi','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nTrên trang giấy thử có một ô tin nhắn để trống. Thay vì viết hộ nhân vật, bản demo mời người đọc kiểm tra bàn phím, nút quay lại và khả năng tiếp tục từ phần trăm đã lưu.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 13:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000007','91000000-0000-0000-0000-000000000004',1,'Quỹ đạo màu xanh','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nNhững vòng tròn nhiều màu trôi qua nền xanh như các điểm mốc của một bài kiểm tra thị giác. Mỗi mốc mang một con số, giúp xác định vị trí cuộn mà không gán ý nghĩa cốt truyện cho bìa.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000008','91000000-0000-0000-0000-000000000004',2,'Ngôi sao đánh dấu','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột ngôi sao giấy nằm ở giữa trang, bên dưới là ba khoảng văn có độ dài khác nhau. Bố cục được tạo để thử font lớn, khoảng cách dòng và việc khôi phục vị trí sau khi mở lại ứng dụng.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000009','91000000-0000-0000-0000-000000000005',1,'Trang thử màu lam','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMàn hình chuyển sang một sắc lam dịu và hiển thị các câu hoàn toàn mới về việc chăm sóc trải nghiệm đọc. Không chi tiết tiểu sử hay sự kiện nào của tác phẩm được đưa vào dữ liệu này.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000010','91000000-0000-0000-0000-000000000005',2,'Một khoảng nghỉ','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nGiữa hai đoạn văn là khoảng trắng rộng để người dùng nhận biết tiến độ cuộn. Khi rời chương, ứng dụng cần lưu điểm dừng nhưng không biến thao tác lưu phần trăm thành một lượt đọc mới.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000011','91000000-0000-0000-0000-000000000006',1,'Vòng sáng thử nghiệm','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột vòng sáng tưởng tượng đi qua ba mức độ đậm nhạt, tạo nhịp cho trang đọc demo. Đây chỉ là chỉ dẫn thị giác dùng để thử theme, không phải mô tả sự kiện hay nhân vật của tác phẩm.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000012','91000000-0000-0000-0000-000000000006',2,'Khi màn hình dịu lại','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nPhần cuối giảm số câu và tăng khoảng cách, giúp quan sát thanh công cụ tự ẩn rồi xuất hiện. Người đọc có thể chuyển nền mà không làm thay đổi chương hoặc gửi sai tiến độ.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000013','91000000-0000-0000-0000-000000000007',1,'Một trăm ô trống','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nBản demo xếp những ô vuông nhỏ thành một hàng tượng trưng cho các mốc đọc, nhưng không gán chúng với nội dung sách. Mục tiêu là kiểm tra văn bản dài hiển thị ổn định và dễ theo dõi.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000014','91000000-0000-0000-0000-000000000007',2,'Giới hạn của trang thử','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nTrang này có điểm bắt đầu, điểm dừng và một nút chuyển chương rõ ràng. Những giới hạn ấy giúp kiểm tra lịch sử đọc, trong khi phần ý nghĩa của tác phẩm vẫn được để nguyên, không suy diễn.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000015','91000000-0000-0000-0000-000000000008',1,'Ngọn đồi bằng giấy','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột ngọn đồi được gấp từ giấy màu, trên đó có các ký hiệu dùng để kiểm tra độ tương phản. Cảnh do dự án tạo không đại diện cho bối cảnh hoặc nhân vật trong tác phẩm.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000016','91000000-0000-0000-0000-000000000008',2,'Mở trang kế tiếp','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nNăm hình tròn xuất hiện theo thứ tự từ nhỏ đến lớn để người đọc thử cuộn chậm. Khi hình cuối rời khỏi màn hình, tiến độ có thể được lưu và khôi phục ở lần mở sau.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000017','91000000-0000-0000-0000-000000000009',1,'Mái nhà mô hình','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột mô hình mái nhà bằng bìa cứng được đặt trên bàn thử giao diện. Ánh đèn, chiếc thang giấy và khoảng trời đều là chi tiết mới do dự án tạo, không phải nội dung sách.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000018','91000000-0000-0000-0000-000000000009',2,'Âm thanh ngoài khung','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nTrang demo không phát âm thanh; nó chỉ dùng những dòng dài ngắn xen kẽ để mô phỏng nhịp đọc. Người dùng có thể thoát ở bất kỳ đoạn nào và kiểm tra thanh Đọc tiếp trên Trang chủ.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000019','91000000-0000-0000-0000-000000000010',1,'Bản đồ không địa danh','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột bản đồ thử chỉ có đường nét và mảng màu, không ghi thành phố hay hành trình cụ thể. Nó cung cấp điểm tựa thị giác cho bài kiểm tra cuộn mà không đặt ra cốt truyện.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000020','91000000-0000-0000-0000-000000000010',2,'Điểm dừng màu cam','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nDấu tròn màu cam đánh dấu gần cuối văn bản, nơi ứng dụng nên ghi nhận phần trăm hiện tại. Nếu mở lại, trình đọc cần trở về dấu này sau khi nội dung đã hoàn tất bố cục.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000021','91000000-0000-0000-0000-000000000011',1,'Hai gam màu','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nTrang thử chia thành hai vùng màu với độ sáng khác nhau để kiểm tra chữ và icon. Vì metadata chưa đầy đủ, đoạn văn không suy luận thể loại, thời đại hoặc mối quan hệ nhân vật.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000022','91000000-0000-0000-0000-000000000011',2,'Đường kẻ giữa trang','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột đường kẻ mảnh phân cách các đoạn, giúp nhận biết khi cỡ chữ thay đổi làm nội dung dồn xuống. Điểm đọc mới chỉ được gửi sau thao tác của người dùng, không phải do theme thay đổi.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000023','91000000-0000-0000-0000-000000000012',1,'Mảng trời đầu trang','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nTrang demo bắt đầu bằng mảng màu sáng và các câu mô tả chính thao tác đọc. Không mùa, địa điểm hay nhân vật nào được khẳng định là thuộc tác phẩm gốc.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000024','91000000-0000-0000-0000-000000000012',2,'Bước qua khung chữ','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMỗi đoạn có độ dài riêng để thử chuyển từ chữ thường sang chữ lớn. Nút chương trước và chương sau vẫn giữ vị trí dễ chạm, còn tiến độ được gắn đúng chương đang mở.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000025','91000000-0000-0000-0000-000000000013',1,'Lớp màu dưới sâu','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nNhững lớp xanh xếp chồng tạo thành nền tưởng tượng cho bài kiểm tra tương phản. Văn bản chỉ nói về giao diện và không tái hiện trải nghiệm, lời kể hoặc nội dung của sách.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000026','91000000-0000-0000-0000-000000000013',2,'Điểm sáng trên màn hình','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nCác điểm sáng nhỏ được nhắc tới như mốc kỹ thuật để người đọc dừng lại. Khi quay về lịch sử, ứng dụng phải hiển thị đúng tên truyện và chương mà không lộ nội dung nếu chương bị ẩn.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000027','91000000-0000-0000-0000-000000000014',1,'Dải màu ấm','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nMột dải màu ấm lan từ trái sang phải trên trang minh họa, phục vụ kiểm tra nền và độ sáng chữ. Không sự kiện nào của tác phẩm thật được mô tả trong phần này.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL),('93000000-0000-0000-0000-000000000028','91000000-0000-0000-0000-000000000014',2,'Khép lại bản thử','Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.\n\nDòng cuối đánh dấu kết thúc bộ văn bản tự sáng tác cho trình đọc. Người dùng có thể quay lại chương đầu, và hệ thống vẫn phải phân biệt hành động đọc lại với request tiến độ đến muộn.',1,0,NULL,NULL,NULL,'2026-11-16 13:09:15','2026-11-16 20:09:15','2026-11-16 20:09:15',NULL);
