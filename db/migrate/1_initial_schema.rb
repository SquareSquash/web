# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

class InitialSchema < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE FUNCTION bugs_calculate_number() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET number = (SELECT COALESCE(MAX(number), 0)+1 FROM bugs oc WHERE oc.environment_id = NEW.environment_id)
                  WHERE id = NEW.id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_decrement_comments_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET comments_count = comments_count - 1
                  WHERE id = OLD.bug_id;
                RETURN OLD;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_decrement_events_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET events_count = events_count - 1
                  WHERE id = OLD.bug_id;
                RETURN OLD;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_decrement_occurrences_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET occurrences_count = occurrences_count - 1
                  WHERE id = OLD.bug_id;
                RETURN OLD;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_increment_comments_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET comments_count = comments_count + 1
                  WHERE id = NEW.bug_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_increment_events_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET events_count = events_count + 1
                  WHERE id = NEW.bug_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_increment_occurrences_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET occurrences_count = occurrences_count + 1
                  WHERE id = NEW.bug_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_move_comments_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET comments_count = comments_count - 1
                  WHERE id = OLD.bug_id;
                UPDATE bugs
                  SET comments_count = comments_count + 1
                  WHERE id = NEW.bug_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_move_events_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET events_count = events_count - 1
                  WHERE id = OLD.bug_id;
                UPDATE bugs
                  SET events_count = events_count + 1
                  WHERE id = NEW.bug_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION bugs_move_occurrences_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE bugs
                  SET occurrences_count = occurrences_count - 1
                  WHERE id = OLD.bug_id;
                UPDATE bugs
                  SET occurrences_count = occurrences_count + 1
                  WHERE id = NEW.bug_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION comments_calculate_number() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE comments
                  SET number = (SELECT COALESCE(MAX(number), 0)+1 FROM comments cc WHERE cc.bug_id = NEW.bug_id)
                  WHERE id = NEW.id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION environments_change_bugs_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
                BEGIN
                  UPDATE environments
                    SET bugs_count = (
                      CASE WHEN NEW.fixed IS NOT TRUE AND NEW.irrelevant IS NOT TRUE
                        THEN bugs_count + 1
                        ELSE bugs_count - 1
                      END)
                    WHERE id = OLD.environment_id;
                  RETURN NEW;
                END;
              $$
    SQL

    execute <<-SQL
      CREATE FUNCTION environments_decrement_bugs_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE environments
                  SET bugs_count = bugs_count - 1
                  WHERE id = OLD.environment_id;
                RETURN OLD;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION environments_increment_bugs_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE environments
                  SET bugs_count = bugs_count + 1
                  WHERE id = NEW.environment_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION environments_move_bugs_count() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE environments
                  SET bugs_count = bugs_count - (
                    CASE
                      WHEN (OLD.fixed IS NOT TRUE AND OLD.irrelevant IS NOT TRUE)
                      THEN 1
                      ELSE 0
                    END)
                  WHERE id = OLD.environment_id;
                UPDATE environments
                  SET bugs_count = bugs_count + (
                    CASE
                      WHEN (NEW.fixed IS NOT TRUE AND NEW.irrelevant IS NOT TRUE)
                      THEN 1
                      ELSE 0
                    END)
                  WHERE id = NEW.environment_id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION notify_bug_update() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              DECLARE
                occurrences_changed CHARACTER VARYING(5);
                comments_changed CHARACTER VARYING(5);
                events_changed CHARACTER VARYING(5);
              BEGIN
                occurrences_changed := (CASE WHEN OLD.occurrences_count IS DISTINCT FROM NEW.occurrences_count THEN 'TRUE' ELSE 'FALSE' END);
                comments_changed    := (CASE WHEN OLD.comments_count    IS DISTINCT FROM NEW.comments_count    THEN 'TRUE' ELSE 'FALSE' END);
                events_changed      := (CASE WHEN OLD.events_count      IS DISTINCT FROM NEW.events_count      THEN 'TRUE' ELSE 'FALSE' END);
                PERFORM pg_notify('ws_env_' || NEW.environment_id, '{"table":"' || TG_TABLE_NAME || '","id":' || NEW.id || ',"occurrences_count_changed":' || occurrences_changed || ',"comments_count_changed":' || comments_changed || ',"events_count_changed":' || events_changed || '}');
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION notify_env_update() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              DECLARE
                bugs_changed CHARACTER VARYING(5);
              BEGIN
                bugs_changed := (CASE WHEN OLD.bugs_count IS DISTINCT FROM NEW.bugs_count THEN 'TRUE' ELSE 'FALSE' END);
                PERFORM pg_notify('ws_proj_' || NEW.project_id, '{"table":"' || TG_TABLE_NAME || '","id":' || NEW.id || ',"bugs_count_changed":' || bugs_changed || '}');
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE FUNCTION occurrences_calculate_number() RETURNS trigger
          LANGUAGE plpgsql
          AS $$
              BEGIN
                UPDATE occurrences
                  SET number = (SELECT COALESCE(MAX(number), 0)+1 FROM occurrences oc WHERE oc.bug_id = NEW.bug_id)
                  WHERE id = NEW.id;
                RETURN NEW;
              END;
            $$
    SQL

    execute <<-SQL
      CREATE TABLE users (
          id SERIAL PRIMARY KEY,
          created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          metadata TEXT,
          updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          username CHARACTER VARYING(50) NOT NULL CHECK (CHAR_LENGTH(username) > 0)
      )
    SQL

    execute <<-SQL
      CREATE TABLE projects (
          id SERIAL PRIMARY KEY,
          api_key CHARACTER(36) NOT NULL UNIQUE,
          created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          default_environment_id INTEGER,
          metadata TEXT,
          name CHARACTER VARYING(126) NOT NULL CHECK (CHAR_LENGTH(name) > 0),
          owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
          repository_url CHARACTER VARYING(255) NOT NULL,
          updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE environments (
          id SERIAL PRIMARY KEY,
          bugs_count INTEGER DEFAULT 0 NOT NULL CHECK (bugs_count >= 0),
          name CHARACTER VARYING(100) NOT NULL CHECK (CHAR_LENGTH(name) > 0),
          project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          metadata TEXT
      )
    SQL

    execute <<-SQL
      ALTER TABLE projects ADD CONSTRAINT projects_default_environment_id_fkey FOREIGN KEY (default_environment_id) REFERENCES environments(id) ON DELETE SET NULL
    SQL

    execute <<-SQL
      CREATE TABLE deploys (
          id SERIAL PRIMARY KEY,
          build CHARACTER VARYING(40),
          deployed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          environment_id INTEGER NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
          hostname CHARACTER VARYING(126),
          revision CHARACTER(40) NOT NULL,
          version CHARACTER VARYING(126)
      )
    SQL

    execute <<-SQL
      CREATE TABLE bugs (
          id SERIAL PRIMARY KEY,
          assigned_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
          blamed_revision CHARACTER(40),
          class_name CHARACTER VARYING(128) NOT NULL CHECK (CHAR_LENGTH(class_name) > 0),
          client CHARACTER VARYING(32) NOT NULL,
          comments_count INTEGER DEFAULT 0 NOT NULL CHECK (comments_count >= 0),
          deploy_id INTEGER REFERENCES deploys(id) ON DELETE SET NULL,
          duplicate_of_id INTEGER,
          environment_id INTEGER NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
          events_count INTEGER DEFAULT 0 NOT NULL CHECK (events_count >= 0),
          file CHARACTER VARYING(255) NOT NULL CHECK (CHAR_LENGTH(file) > 0),
          first_occurrence TIMESTAMP WITHOUT TIME ZONE,
          fixed BOOLEAN DEFAULT FALSE NOT NULL,
          fix_deployed BOOLEAN DEFAULT FALSE NOT NULL,
          irrelevant BOOLEAN DEFAULT FALSE NOT NULL,
          latest_occurrence TIMESTAMP WITHOUT TIME ZONE,
          line INTEGER NOT NULL CHECK (line > 0),
          metadata TEXT,
          number INTEGER CHECK (number > 0),
          occurrences_count INTEGER DEFAULT 0 NOT NULL CHECK (occurrences_count >= 0),
          resolution_revision CHARACTER(40),
          revision CHARACTER(40) NOT NULL,
          searchable_text TSVECTOR,
          CHECK (fix_deployed IS TRUE AND fixed IS TRUE OR fix_deployed IS FALSE)
      )
    SQL

    execute <<-SQL
      ALTER TABLE bugs ADD CONSTRAINT bugs_duplicate_of_id_fkey FOREIGN KEY (duplicate_of_id) REFERENCES bugs(id) ON DELETE CASCADE
    SQL

    execute <<-SQL
      CREATE TABLE comments (
          id SERIAL PRIMARY KEY,
          bug_id INTEGER NOT NULL REFERENCES bugs(id) ON DELETE CASCADE,
          created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          metadata TEXT,
          number INTEGER CHECK (number > 0),
          updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          user_id INTEGER REFERENCES users(id) ON DELETE SET NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE emails (
          id SERIAL PRIMARY KEY,
          "primary" BOOLEAN DEFAULT FALSE NOT NULL,
          email CHARACTER VARYING(255) NOT NULL,
          project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
      )
    SQL

    execute <<-SQL
      CREATE TABLE events (
          id SERIAL PRIMARY KEY,
          bug_id INTEGER NOT NULL REFERENCES bugs(id) ON DELETE CASCADE,
          created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          data TEXT,
          kind CHARACTER VARYING(32) NOT NULL,
          user_id INTEGER REFERENCES users(id) ON DELETE SET NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE memberships (
          project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          admin BOOLEAN DEFAULT FALSE NOT NULL,
          created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          metadata TEXT,
          PRIMARY KEY (project_id, user_id)
      )
    SQL

    execute <<-SQL
      CREATE TABLE notification_thresholds (
          bug_id INTEGER NOT NULL REFERENCES bugs(id) ON DELETE CASCADE,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          last_tripped_at TIMESTAMP WITHOUT TIME ZONE,
          period INTEGER NOT NULL CHECK (period > 0),
          threshold INTEGER NOT NULL CHECK (threshold > 0),
          PRIMARY KEY (bug_id, user_id)
      )
    SQL

    execute <<-SQL

      CREATE TABLE obfuscation_maps (
          id SERIAL PRIMARY KEY,
          deploy_id INTEGER NOT NULL REFERENCES deploys(id) ON DELETE CASCADE,
          namespace TEXT
      )
    SQL

    execute <<-SQL
      CREATE TABLE occurrences (
          id SERIAL PRIMARY KEY,
          bug_id INTEGER NOT NULL REFERENCES bugs(id) ON DELETE CASCADE,
          client CHARACTER VARYING(32) NOT NULL,
          metadata TEXT,
          number INTEGER CHECK (number > 0),
          occurred_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          redirect_target_id INTEGER,
          revision CHARACTER(40) NOT NULL,
          symbolication_id uuid
      )
    SQL

    execute <<-SQL
      ALTER TABLE occurrences ADD CONSTRAINT occurrences_redirect_target_id_fkey FOREIGN KEY (redirect_target_id) REFERENCES occurrences(id) ON DELETE CASCADE
    SQL

    execute <<-SQL
      CREATE TABLE slugs (
          id SERIAL PRIMARY KEY,
          active BOOLEAN DEFAULT TRUE NOT NULL,
          created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
          scope CHARACTER VARYING(126),
          slug CHARACTER VARYING(126) NOT NULL CHECK (CHAR_LENGTH(slug) > 0),
          sluggable_id INTEGER NOT NULL,
          sluggable_type CHARACTER VARYING(32) NOT NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE source_maps (
          id SERIAL PRIMARY KEY,
          environment_id INTEGER NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
          map TEXT,
          revision CHARACTER(40) NOT NULL
      )
    SQL

    execute <<-SQL
      CREATE TABLE symbolications (
          uuid uuid NOT NULL PRIMARY KEY,
          lines TEXT,
          symbols TEXT
      )
    SQL

    execute <<-SQL
      CREATE TABLE user_events (
          event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          created_at TIMESTAMP WITHOUT TIME ZONE,
          PRIMARY KEY (event_id, user_id)
      )
    SQL

    execute <<-SQL
      CREATE TABLE watches (
          bug_id INTEGER NOT NULL REFERENCES bugs(id) ON DELETE CASCADE,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          created_at TIMESTAMP WITHOUT TIME ZONE,
          PRIMARY KEY (bug_id, user_id)
      )
    SQL

    execute <<-SQL
      CREATE INDEX bugs_env_fo ON bugs (environment_id, deploy_id, assigned_user_id, fixed, irrelevant, latest_occurrence, number)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_env_lo ON bugs (environment_id, deploy_id, assigned_user_id, fixed, irrelevant, first_occurrence, number)
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX bugs_env_number ON bugs (environment_id, number)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_env_oc ON bugs (environment_id, deploy_id, assigned_user_id, fixed, irrelevant, occurrences_count, number)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_env_user ON bugs (environment_id, assigned_user_id, fixed, irrelevant)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_environment_textsearch ON bugs USING gin (searchable_text)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_find_for_occ1 ON bugs (environment_id, class_name, file, line, blamed_revision, deploy_id)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_find_for_occ2 ON bugs (environment_id, class_name, file, line, blamed_revision, fixed)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_user ON bugs (assigned_user_id, fixed, irrelevant)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_user_recency ON bugs (assigned_user_id, latest_occurrence, number)
    SQL

    execute <<-SQL
      CREATE INDEX bugs_fixed ON bugs (fixed)
    SQL

    execute <<-SQL
      CREATE INDEX comments_bug ON comments (bug_id, created_at)
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX comments_number ON comments (bug_id, number)
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX deploys_env_build ON deploys (environment_id, build)
    SQL

    execute <<-SQL
      CREATE INDEX deploys_env_revision ON deploys (environment_id, revision, deployed_at)
    SQL

    execute <<-SQL
      CREATE INDEX deploys_env_time ON deploys (environment_id, deployed_at)
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX emails_email_user ON emails (LOWER(email), project_id, user_id)
    SQL

    execute <<-SQL
      CREATE INDEX emails_primary ON emails (user_id, "primary")
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX environments_name ON environments (project_id, LOWER(name))
    SQL

    execute <<-SQL
      CREATE INDEX events_bug ON events (bug_id, created_at)
    SQL

    execute <<-SQL
      CREATE INDEX occurrences_bug ON occurrences (bug_id, occurred_at)
    SQL

    execute <<-SQL
      CREATE INDEX occurrences_bug_revision ON occurrences (bug_id, revision, occurred_at)
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX occurrences_number ON occurrences (bug_id, number)
    SQL

    execute <<-SQL
      CREATE INDEX projects_name ON projects (LOWER(name) TEXT_pattern_ops)
    SQL

    execute <<-SQL
      CREATE INDEX projects_owner ON projects (owner_id)
    SQL

    execute <<-SQL
      CREATE INDEX slugs_for_record ON slugs (sluggable_type, sluggable_id, active)
    SQL

    execute <<-SQL
      CREATE UNIQUE INDEX slugs_unique ON slugs (sluggable_type, LOWER(scope), LOWER(slug))
    SQL

    execute <<-SQL
      CREATE INDEX source_maps_env_revision ON source_maps (environment_id, revision)
    SQL

    execute <<-SQL
      CREATE INDEX user_events_time ON user_events (event_id, created_at)
    SQL

    execute <<-SQL
      CREATE INDEX users_username ON users (LOWER(username) TEXT_pattern_ops)
    SQL

    execute <<-SQL
      CREATE RULE occurrences_set_first AS
        ON INSERT TO occurrences DO
          UPDATE bugs
            SET first_occurrence = NEW.occurred_at
            WHERE (bugs.id = NEW.bug_id)
              AND (bugs.first_occurrence IS NULL)
    SQL

    execute <<-SQL
      CREATE RULE occurrences_set_latest AS
        ON INSERT TO occurrences DO
          UPDATE bugs
            SET latest_occurrence = NEW.occurred_at
            WHERE (bugs.id = NEW.bug_id)
              AND (bugs.latest_occurrence IS NULL)
              OR (bugs.latest_occurrence < NEW.occurred_at)
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_comments_delete
        AFTER DELETE ON comments
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_decrement_comments_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_comments_insert
        AFTER INSERT ON comments
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_increment_comments_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_comments_move
        AFTER UPDATE ON comments
        FOR EACH ROW WHEN (OLD.bug_id <> NEW.bug_id)
          EXECUTE PROCEDURE bugs_move_comments_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_events_delete
        AFTER DELETE ON events
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_decrement_events_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_events_insert AFTER INSERT ON events
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_increment_events_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_events_move AFTER UPDATE ON events
        FOR EACH ROW WHEN (OLD.bug_id <> NEW.bug_id)
          EXECUTE PROCEDURE bugs_move_events_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_notify AFTER UPDATE ON bugs
        FOR EACH ROW
          WHEN (
            (OLD.occurrences_count IS DISTINCT FROM NEW.occurrences_count)
            OR (OLD.comments_count IS DISTINCT FROM NEW.comments_count)
            OR (OLD.events_count IS DISTINCT FROM NEW.events_count)
          )
          EXECUTE PROCEDURE notify_bug_update()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_occurrences_delete
        AFTER DELETE ON occurrences
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_decrement_occurrences_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_occurrences_insert AFTER INSERT ON occurrences
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_increment_occurrences_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_occurrences_move AFTER UPDATE ON occurrences
        FOR EACH ROW WHEN (OLD.bug_id <> NEW.bug_id)
          EXECUTE PROCEDURE bugs_move_occurrences_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER bugs_set_number AFTER INSERT ON bugs
        FOR EACH ROW
          EXECUTE PROCEDURE bugs_calculate_number()
    SQL

    execute <<-SQL
      CREATE TRIGGER comments_set_number AFTER INSERT ON comments
        FOR EACH ROW
          EXECUTE PROCEDURE comments_calculate_number()
    SQL

    execute <<-SQL
      CREATE TRIGGER environments_bugs_delete
        AFTER DELETE ON bugs
        FOR EACH ROW WHEN ((OLD.fixed IS NOT TRUE) AND (OLD.irrelevant IS NOT TRUE))
          EXECUTE PROCEDURE environments_decrement_bugs_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER environments_bugs_insert
        AFTER INSERT ON bugs
        FOR EACH ROW WHEN ((NEW.fixed IS NOT TRUE) AND (NEW.irrelevant IS NOT TRUE))
          EXECUTE PROCEDURE environments_increment_bugs_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER environments_bugs_move
        AFTER UPDATE ON bugs
        FOR EACH ROW WHEN (OLD.environment_id <> NEW.environment_id)
          EXECUTE PROCEDURE environments_move_bugs_count()
    SQL

    execute <<-SQL
      CREATE TRIGGER environments_bugs_update
        AFTER UPDATE ON bugs
        FOR EACH ROW WHEN (
          (
            (old.environment_id = new.environment_id)
            AND (
              (
                (
                  (old.fixed IS NOT TRUE)
                  AND (old.irrelevant IS NOT TRUE)
                ) AND (
                  NOT (
                    (new.fixed IS NOT TRUE)
                    AND (new.irrelevant IS NOT TRUE)
                  )
                )
              ) OR (
                (
                  (new.fixed IS NOT TRUE)
                  AND (new.irrelevant IS NOT TRUE)
                ) AND (
                  NOT (
                    (old.fixed IS NOT TRUE)
                    AND (old.irrelevant IS NOT TRUE)
                  )
                )
              )
            )
          )
        )
        EXECUTE PROCEDURE environments_change_bugs_count();
    SQL

    execute <<-SQL
      CREATE TRIGGER environments_notify
        AFTER UPDATE ON environments
        FOR EACH ROW WHEN (OLD.bugs_count IS DISTINCT FROM NEW.bugs_count)
          EXECUTE PROCEDURE notify_env_update()
    SQL

    execute <<-SQL
      CREATE TRIGGER occurrences_set_number
        AFTER INSERT ON occurrences
        FOR EACH ROW
          EXECUTE PROCEDURE occurrences_calculate_number()
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
