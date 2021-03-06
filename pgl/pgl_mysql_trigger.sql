DROP TRIGGER IF EXISTS pgl_new_user;
DROP TRIGGER IF EXISTS pgl_new_project;
DROP TRIGGER IF EXISTS pgl_update_project;

delimiter //

CREATE TRIGGER pgl_new_user
AFTER INSERT ON users FOR EACH ROW
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE m_projects_id integer;
    DECLARE cur CURSOR FOR SELECT project_id FROM user_team_project_relationships WHERE user_team_id = (SELECT id FROM user_teams WHERE name = "pgl_reporters");
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; 

    OPEN cur;
        ins_loop: LOOP
            FETCH cur INTO m_projects_id;
            IF done THEN
                LEAVE ins_loop;
            END IF;

            INSERT INTO users_projects (user_id, project_id, created_at, updated_at, project_access)
            VALUES (NEW.id, m_projects_id, now(), now(), 20);
        END LOOP;
    CLOSE cur;

    INSERT INTO user_team_user_relationships (user_id, user_team_id, permission, created_at, updated_at) VALUES (NEW.id, (SELECT id FROM user_teams WHERE name = "pgl_reporters"), 20, now(), now());
END//

DELIMITER ;
delimiter //

CREATE TRIGGER pgl_new_project
AFTER INSERT ON projects FOR EACH ROW
BEGIN
    DECLARE m_users_id integer;
    DECLARE done INT DEFAULT FALSE;

    DECLARE cur CURSOR FOR SELECT user_id FROM user_team_user_relationships WHERE user_team_id = (SELECT id FROM user_teams WHERE name = "pgl_reporters");
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    IF NEW.public = 1 THEN
        OPEN cur;
            ins_loop: LOOP
                FETCH cur INTO m_users_id;
                IF done THEN
                    LEAVE ins_loop;
                END IF;

                IF m_users_id <> NEW.creator_id THEN
                    INSERT INTO users_projects (user_id, project_id, created_at, updated_at, project_access)
                    VALUES (m_users_id, NEW.id, now(), now(), 20);
                END IF;
            END LOOP;
        CLOSE cur;

        INSERT INTO user_team_project_relationships (project_id, user_team_id, greatest_access, created_at, updated_at) VALUES (NEW.id, (SELECT id FROM user_teams WHERE name = "pgl_reporters"), 20, now(), now());
    END IF;
END//

DELIMITER ;
delimiter //

CREATE TRIGGER pgl_update_project
AFTER UPDATE ON projects FOR EACH ROW
BEGIN
    DECLARE m_users_id integer;
    DECLARE done INT DEFAULT FALSE;
    DECLARE rows INT;
    DECLARE cur CURSOR FOR SELECT user_id FROM user_team_user_relationships WHERE user_team_id = (SELECT id FROM user_teams WHERE name = "pgl_reporters");
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    IF NEW.public <> OLD.public THEN
        if NEW.public = 1 THEN

            OPEN cur;
                ins_loop: LOOP
                    FETCH cur INTO m_users_id;
                    IF done THEN
                        LEAVE ins_loop;
                    END IF;

                    IF m_users_id <> NEW.creator_id THEN
                        SELECT count(*) INTO rows FROM users_projects WHERE user_id = m_users_id AND project_id = OLD.id;
                        IF rows = 0 THEN
                            INSERT INTO users_projects (user_id, project_id, created_at, updated_at, project_access)
                            VALUES (m_users_id, NEW.id, now(), now(), 20);
                        END IF;
                    END IF;
                END LOOP;
            CLOSE cur;
            INSERT INTO user_team_project_relationships (project_id, user_team_id, greatest_access, created_at, updated_at) VALUES (NEW.id, (SELECT id FROM user_teams WHERE name = "pgl_reporters"), 20, now(), now());
        ELSE
            OPEN cur;
                ins_loop: LOOP
                    FETCH cur INTO m_users_id;
                    IF done THEN
                        LEAVE ins_loop;
                    END IF;

                    SELECT project_access INTO rows FROM users_projects WHERE user_id = m_users_id AND project_id = OLD.id LIMIT 1;
                    -- If project permission is reporter (20), or lower
                    IF rows < 21 THEN
                        DELETE FROM users_projects WHERE user_id = m_users_id AND project_id = OLD.id;
                    END IF;
                END LOOP;
            CLOSE cur;
            DELETE FROM user_team_project_relationships WHERE user_team_id = (SELECT id FROM user_teams WHERE name = "pgl_reporters") AND project_id = OLD.id;
        END IF;
    END IF;
END//
DELIMITER ;