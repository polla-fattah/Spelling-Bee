# Zhyar Spelling - Project Overview

## Description
**Zhyar Spelling** is a Flutter-based educational application designed to help students master spelling and vocabulary through a structured, grade-based curriculum.

## Key Features
- **Structured Curriculum:** Vocabulary organized by Grades (1-6) and Steps (10 words per step).
- **Gamified Progress:** Tracking via `user_stats` table, awarding tokens, and managing level advancement.
- **Interactive Quizzes:** Integrated Text-to-Speech (TTS) for spelling exercises.
- **Cross-Platform Support:** Runs on Android, iOS, and Desktop (Windows, Linux, macOS).

## Technical Stack
- **Framework:** Flutter
- **Database:** SQLite (via `sqflite` and `sqflite_common_ffi`)
- **State/Service:** `DatabaseHelper` for data persistence.
- **Packages:** `flutter_tts`, `path_provider`, `sqflite`.

## Data Model
- **Word:** Represents a vocabulary item with grade, step, and pronunciation data.
- **UserStats:** Tracks current grade, current step, and accumulated tokens.

## Recent Maintenance (Feb 18, 2026)
- **Code Fixes:** Resolved syntax errors in `calendar_screen.dart`, fixed parameter mismatches in `QuizScreen` calls, and addressed missing database methods in `DatabaseHelper`.
- **Consistency:** Standardized terminology from 'stage' to 'grade' across the codebase to match the database schema.
- **Verification:** Successfully performed a debug build of the Android APK.
