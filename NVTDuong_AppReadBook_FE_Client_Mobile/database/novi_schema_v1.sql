-- Novi clean schema v1
-- MySQL 8.x. Store all application timestamps in UTC.
-- This file creates empty tables only and does not overwrite the legacy database.

CREATE DATABASE IF NOT EXISTS `novi`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE `novi`;

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- Keep the clean Novi schema isolated from legacy `read_book` tables. Running
-- this script repeatedly is safe, but it must not reuse similarly named legacy
-- tables whose columns may have a different collation.
CREATE DATABASE IF NOT EXISTS `novi`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE `novi`;

CREATE TABLE IF NOT EXISTS `user` (
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

CREATE TABLE IF NOT EXISTS `password_reset` (
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

CREATE TABLE IF NOT EXISTS `category` (
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

CREATE TABLE IF NOT EXISTS `novel` (
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

CREATE TABLE IF NOT EXISTS `novel_category` (
  `novel_id` CHAR(36) NOT NULL,
  `category_id` CHAR(36) NOT NULL,
  PRIMARY KEY (`novel_id`, `category_id`),
  KEY `idx_novel_category_category` (`category_id`, `novel_id`),
  CONSTRAINT `fk_novel_category_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_novel_category_category` FOREIGN KEY (`category_id`) REFERENCES `category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chapter` (
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

CREATE TABLE IF NOT EXISTS `novel_revision` (
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

CREATE TABLE IF NOT EXISTS `chapter_revision` (
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

CREATE TABLE IF NOT EXISTS `library_item` (
  `user_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `novel_id`),
  KEY `idx_library_recent` (`user_id`, `created_at`),
  KEY `idx_library_interest` (`novel_id`, `created_at`),
  CONSTRAINT `fk_library_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_library_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reading_progress` (
  `user_id` CHAR(36) NOT NULL,
  `novel_id` CHAR(36) NOT NULL,
  `chapter_id` CHAR(36) NOT NULL,
  `position_percent` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `novel_id`),
  KEY `idx_reading_progress_recent` (`user_id`, `updated_at`),
  KEY `idx_reading_progress_chapter` (`novel_id`, `chapter_id`),
  CONSTRAINT `fk_reading_progress_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_progress_novel` FOREIGN KEY (`novel_id`) REFERENCES `novel` (`novel_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reading_progress_chapter` FOREIGN KEY (`novel_id`, `chapter_id`) REFERENCES `chapter` (`novel_id`, `chapter_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_reading_progress_position` CHECK (`position_percent` BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reading_history` (
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

CREATE TABLE IF NOT EXISTS `chapter_view` (
  `view_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `chapter_id` CHAR(36) NOT NULL,
  `user_id` CHAR(36) NULL,
  `viewer_key_hash` CHAR(64) NULL COMMENT 'privacy-preserving key used to reduce duplicate anonymous views',
  `viewed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`view_id`),
  KEY `idx_chapter_view_statistics` (`chapter_id`, `viewed_at`),
  KEY `idx_chapter_view_user` (`user_id`, `viewed_at`),
  CONSTRAINT `fk_chapter_view_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapter` (`chapter_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_chapter_view_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `donation` (
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

CREATE TABLE IF NOT EXISTS `donation_event` (
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

CREATE TABLE IF NOT EXISTS `content_report` (
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

CREATE TABLE IF NOT EXISTS `similarity_check` (
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

CREATE TABLE IF NOT EXISTS `similarity_match` (
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
  CONSTRAINT `ck_similarity_match_percent` CHECK (`similarity_percent` BETWEEN 0 AND 100),
  CONSTRAINT `ck_similarity_match_not_self` CHECK (`matched_chapter_id` IS NULL OR `matched_chapter_id` <> `chapter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
