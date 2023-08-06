DROP SCHEMA IF EXISTS projet CASCADE;
CREATE SCHEMA projet;

----------------
--CREATE TABLE--
----------------
CREATE TABLE projet.etudiants
(
    id_etudiant SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL CHECK ( nom <> '' ),
    prenom VARCHAR(100) NOT NULL CHECK ( prenom <> '' ),
    email VARCHAR(100) NOT NULL UNIQUE CHECK( email SIMILAR TO '%_@_%.__%'),
    mdp CHAR(60) NOT NULL CHECK ( mdp <> '' ),
    bloc INTEGER CHECK (bloc IN (1,2,3)),
    nb_credits_acquis INTEGER NOT NULL DEFAULT 0 CHECK ( nb_credits_acquis >= 0 )
);
CREATE TABLE projet.paes
(
    id_pae SERIAL PRIMARY KEY,
    id_etudiant INTEGER REFERENCES projet.etudiants(id_etudiant),
    valide BOOLEAN NOT NULL DEFAULT false,
    nb_credits_pae INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE projet.ues
(
    id_ue SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE CHECK(code SIMILAR TO 'BINV[1-3]%'),
    nom VARCHAR(100) NOT NULL CHECK ( nom <> '' ),
    bloc INTEGER check (bloc IN (1,2,3)) NOT NULL ,
    nb_credits INTEGER NOT NULL CHECK ( nb_credits>0 ),
    nb_inscrits INTEGER NOT NULL DEFAULT 0 CHECK( nb_inscrits >= 0 )
);
CREATE TABLE projet.lignes_pae
(
    id_pae INTEGER NOT NULL REFERENCES projet.paes(id_pae),
    id_ue INTEGER NOT NULL REFERENCES projet.ues(id_ue),
    CONSTRAINT li_pae_pk PRIMARY KEY (id_pae, id_ue)
);
CREATE TABLE projet.ues_reussies
(
    id_ue INTEGER NOT NULL REFERENCES projet.ues (id_ue)  ,
    id_etudiant INTEGER NOT NULL REFERENCES projet.etudiants (id_etudiant) ,
    CONSTRAINT ue_reussie_pkey PRIMARY KEY (id_ue, id_etudiant)
);

CREATE TABLE projet.ues_prerequis
(
    id_ue_prerequis INTEGER NOT NULL REFERENCES projet.ues (id_ue)  ,
    id_ue_suite INTEGER NOT NULL REFERENCES projet.ues (id_ue) ,
    CONSTRAINT ue_prerequis_pkey PRIMARY KEY (id_ue_prerequis, id_ue_suite),
    CHECK ( id_ue_prerequis<>ues_prerequis.id_ue_suite )
);
------------------------
-- DEBUT DES TRIGGERS --
------------------------

-- Creer un PAE à un nouvel etudiant --
CREATE OR REPLACE FUNCTION projet.ajouterPaeNouvelEtudiant() RETURNS TRIGGER AS $$
DECLARE
BEGIN
INSERT INTO projet.paes (id_etudiant) VALUES (NEW.id_etudiant);
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER etudiants_after AFTER INSERT ON projet.etudiants FOR EACH ROW
    EXECUTE PROCEDURE projet.ajouterPaeNouvelEtudiant();


-- Check que le bloc dans le code correspond au bloc --
CREATE OR REPLACE FUNCTION projet.checkCodeWithBloc() RETURNS TRIGGER AS $$
DECLARE
BEGIN
    IF CAST(substr(NEW.code,5,1) AS INTEGER) != NEW.bloc THEN
        RAISE 'Le bloc dans le code ne correspond pas au bloc entré';
end if;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ues_before BEFORE INSERT ON projet.ues FOR EACH ROW
    EXECUTE PROCEDURE projet.checkCodeWithBloc();


-- Met à jour le nb_credits_pae --
CREATE OR REPLACE FUNCTION projet.updateNbCreditsPae() RETURNS TRIGGER AS $$
DECLARE
nv_nb_cred INTEGER;
    nb_cred_pae INTEGER;
    nb_cred_ue INTEGER;
BEGIN
SELECT p.nb_credits_pae FROM projet.paes p WHERE p.id_pae = NEW.id_pae INTO nb_cred_pae;
SELECT u.nb_credits FROM projet.ues u WHERE u.id_ue = NEW.id_ue INTO nb_cred_ue;
nv_nb_cred = nb_cred_pae + nb_cred_ue;
UPDATE projet.paes SET nb_credits_pae = nv_nb_cred WHERE id_pae = NEW.id_pae;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lignes_pae_trigger_after AFTER INSERT ON projet.lignes_pae FOR EACH ROW
    EXECUTE PROCEDURE projet.updateNbCreditsPae();

-- On check que l'ue ajouté n'est pas déjà validée par l'étudiant --
CREATE OR REPLACE FUNCTION projet.checkUeAjouteePasDejaValidee() RETURNS TRIGGER AS $$
DECLARE
etudiant_id INTEGER;
    coursValide INTEGER;
    nb_prerequis INTEGER;
BEGIN
SELECT e.id_etudiant FROM projet.etudiants e, projet.paes p WHERE p.id_etudiant = e.id_etudiant AND p.id_pae = NEW.id_pae INTO etudiant_id; -- get l'id de l'étudiant --
SELECT count(ur.*) FROM projet.ues_reussies ur WHERE ur.id_etudiant =  etudiant_id AND ur.id_ue = NEW.id_ue INTO coursValide;
-- cas où l'ue est déjà validée
IF coursValide = 1 THEN
        RAISE 'L''UE est déjà validée';
end if;
    IF (SELECT count(lp.*) FROM projet.lignes_pae lp WHERE lp.id_ue = NEW.id_ue AND lp.id_pae = NEW.id_pae) = 1 THEN
        RAISE 'L''UE se trouve déjà dans votre PAE';
END IF;
    -- cas où le PAE est déjà validé
    IF (SELECT p.valide FROM projet.paes p WHERE id_etudiant = etudiant_id) THEN
        RAISE 'Votre PAE est déjà validé. Aucune modification n''est autorisée';
end if;
    -- cas où on a pas valider le prerequis
SELECT count(up.*) FROM projet.ues_prerequis up WHERE up.id_ue_suite = NEW.id_ue INTO nb_prerequis;
IF nb_prerequis > 0 THEN
        IF (SELECT up.id_ue_prerequis FROM projet.ues_prerequis up WHERE up.id_ue_suite = NEW.id_ue AND up.id_ue_prerequis NOT IN (SELECT ur.id_ue FROM projet.ues_reussies ur WHERE ur.id_etudiant = etudiant_id)) != nb_prerequis THEN
            RAISE 'Vous n''avez pas validé tous les prerequis de cette UE';
end if;
end if;
    -- cas où etudiant a -30 crédits et l'ue n'est pas du bloc 1
    IF ((SELECT e.nb_credits_acquis FROM projet.etudiants e WHERE e.id_etudiant = etudiant_id) < 30) AND ((SELECT u.bloc FROM projet.ues u WHERE u.id_ue = NEW.id_ue) != 1) THEN
        RAISE 'Cette UE n''est pas autorisée aux étudiants du bloc 1';
end if;
RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER lignes_pae_trigger_before_ue BEFORE INSERT ON projet.lignes_pae FOR EACH ROW
    EXECUTE PROCEDURE projet.checkUeAjouteePasDejaValidee();

-- On check que l'ue prerequis a un bloc inferieur a celui de suite --
CREATE OR REPLACE FUNCTION projet.checkBlocUePrerequisInferieurBlocUeSuite() RETURNS TRIGGER AS $$
DECLARE
bloc_prerequis INTEGER;
    bloc_suite INTEGER;
BEGIN
    IF NOT EXISTS(SELECT * FROM projet.ues ue
                  WHERE ue.id_ue=NEW.id_ue_prerequis OR ue.id_ue=NEW.id_ue_suite) THEN
        RAISE 'Veuillez entrez des Ues qui existent';
END IF;
SELECT ue.bloc FROM projet.ues ue WHERE ue.id_ue=NEW.id_ue_prerequis INTO bloc_prerequis;
SELECT ue.bloc FROM projet.ues ue WHERE ue.id_ue=NEW.id_ue_suite INTO bloc_suite;
IF bloc_prerequis>=bloc_suite THEN
        RAISE 'Le bloc de l''UE prerequis doit être strictement inférieur à l''UE qui doit l''avoir comme prérequis';
end if;
RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ues_prerequis_trigger BEFORE INSERT ON projet.ues_prerequis FOR EACH ROW
    EXECUTE PROCEDURE projet.checkBlocUePrerequisInferieurBlocUeSuite();





CREATE OR REPLACE FUNCTION projet.checkParamsUesReussies() RETURNS TRIGGER AS $$
DECLARE
BEGIN
    IF NEW.id_etudiant IS NULL THEN
        RAISE 'L''étudiant n''est pas connu dans le système';
    ELSIF NEW.id_ue IS NULL THEN
        RAISE 'L''ue entré n''existe pas';
end if;
RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ues_reussies_trigger_before BEFORE INSERT ON projet.ues_reussies FOR EACH ROW
    EXECUTE PROCEDURE projet.checkParamsUesReussies();









-- On change le nbCreditsAcquis quand un cours est réussi --
CREATE OR REPLACE FUNCTION projet.updateCreditsAcquis() RETURNS TRIGGER AS $$
DECLARE
etudiant_id INTEGER;
    nv_credits_acquis INTEGER;
BEGIN
SELECT e.id_etudiant, e.nb_credits_acquis FROM projet.etudiants e WHERE NEW.id_etudiant = e.id_etudiant INTO etudiant_id, nv_credits_acquis;
nv_credits_acquis := nv_credits_acquis + (SELECT ue.nb_credits FROM projet.ues ue WHERE ue.id_ue = NEW.id_ue);
UPDATE projet.etudiants SET nb_credits_acquis = nv_credits_acquis WHERE id_etudiant = etudiant_id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ues_reussies_trigger AFTER INSERT ON projet.ues_reussies FOR EACH ROW
    EXECUTE PROCEDURE projet.updateCreditsAcquis();

-- supprimer une ue d'une pae --
CREATE OR REPLACE FUNCTION projet.supprimerUeDunPae() RETURNS TRIGGER AS $$
DECLARE
estValide BOOL;
    nv_nb_cred INTEGER;
    nb_credits_UE INTEGER;
BEGIN
SELECT p.valide FROM projet.paes p WHERE p.id_pae=OLD.id_pae INTO estValide;
if estValide=true THEN
        raise 'Le PAE a deja été validé et ne peut plus être modifié';
end if;

SELECT p.nb_credits_pae FROM projet.paes p WHERE p.id_pae=OLD.id_pae INTO nv_nb_cred;
SELECT ue.nb_credits FROM projet.ues ue WHERE ue.id_ue=OLD.id_ue INTO nb_credits_UE;
--update nbCredits du PAE
nv_nb_cred:=nv_nb_cred-nb_credits_UE;
UPDATE projet.paes SET nb_credits_pae = nv_nb_cred WHERE id_pae = OLD.id_pae;

RETURN OLD;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER lignes_pae_trigger_delete BEFORE DELETE ON projet.lignes_pae FOR EACH ROW
    EXECUTE PROCEDURE projet.supprimerUeDunPae();

------------------------
-- FIN DES TRIGGERS --
------------------------


----------------------
-- INSERT ETUDIANTS --
----------------------

INSERT INTO projet.etudiants (nom, prenom, email, mdp) VALUES ('Damas','Christophe','christophe.damas@school.be','$2a$10$LtYTKaUWSsXJW9O6Ex/8.OhDLpq7fdMZgwlnTnf94WXErssmRQA4W');
INSERT INTO projet.etudiants (nom, prenom, email, mdp) VALUES ('Ferneeuw','Stéphanie','stephanie.ferneeuw@school.be','$2a$10$LtYTKaUWSsXJW9O6Ex/8.OhDLpq7fdMZgwlnTnf94WXErssmRQA4W');
INSERT INTO projet.etudiants (nom, prenom, email, mdp) VALUES ('Vander Meulen','José','jose.vander.meulen@school.be','$2a$10$LtYTKaUWSsXJW9O6Ex/8.OhDLpq7fdMZgwlnTnf94WXErssmRQA4W');
INSERT INTO projet.etudiants (nom, prenom, email, mdp) VALUES ('Leconte','Emmeline','emmeline.leconte@school.be','$2a$10$LtYTKaUWSsXJW9O6Ex/8.OhDLpq7fdMZgwlnTnf94WXErssmRQA4W');



----------------
-- INSERT UES --
----------------

INSERT INTO projet.ues (code, nom, bloc, nb_credits) VALUES ('BINV11','BD1',1,31);
INSERT INTO projet.ues (code, nom, bloc, nb_credits) VALUES ('BINV12','APOO',1,16);
INSERT INTO projet.ues (code, nom, bloc, nb_credits) VALUES ('BINV13','Algo',1,13);
INSERT INTO projet.ues (code, nom, bloc, nb_credits) VALUES ('BINV21','BD2',2,42);
INSERT INTO projet.ues (code, nom, bloc, nb_credits) VALUES ('BINV311','Anglais',3,16);
INSERT INTO projet.ues (code, nom, bloc, nb_credits) VALUES ('BINV32','Stage',3,44);

-----------------------
--INSERT UES REUSSIES--
-----------------------

INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (2,1);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (3,1);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (1,2);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (2,2);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (1,3);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (2,3);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (3,3);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (1,4);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (2,4);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (3,4);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (4,4);
INSERT INTO projet.ues_reussies (id_ue, id_etudiant) VALUES (6,4);

--------------------
--INSERT PREREQUIS--
--------------------

INSERT INTO projet.ues_prerequis (id_ue_prerequis, id_ue_suite) VALUES (1,4);
INSERT INTO projet.ues_prerequis (id_ue_prerequis, id_ue_suite) VALUES (4,6);


-----------------------------------------------
-- DEBUT DES PROCEDURES APPLICATION CENTRALE --
-----------------------------------------------

-- ajouter une ue (etape 1) --
CREATE OR REPLACE FUNCTION projet.ajouterUe (code VARCHAR(20),nom VARCHAR(100),bloc integer,nb_credits integer) RETURNS void AS $$
DECLARE
BEGIN
INSERT INTO projet.ues VALUES (DEFAULT,code,nom,bloc,nb_credits,DEFAULT);
END;
$$ LANGUAGE plpgsql;

-- ajouter un prerequis à une ue (etape 2) --
CREATE OR REPLACE FUNCTION projet.ajouterUePrerequis(code_prerequis VARCHAR(20), code_suite VARCHAR(20)) RETURNS void AS $$
DECLARE
id_prerequis INTEGER;
    id_suite INTEGER;
BEGIN
SELECT u1.id_ue, u2.id_ue FROM projet.ues u1, projet.ues u2 WHERE u1.code = code_prerequis
                                                              AND u2.code = code_suite INTO id_prerequis, id_suite;
INSERT INTO projet.ues_prerequis (id_ue_prerequis, id_ue_suite) VALUES (id_prerequis, id_suite);
END;
$$ LANGUAGE plpgsql;

-- ajouter etudiant (etape 3) --
CREATE OR REPLACE FUNCTION projet.ajouterEtudiant(nom VARCHAR(100), prenom VARCHAR(100), email VARCHAR(100), mdp CHAR(60)) RETURNS void AS $$
DECLARE
BEGIN
INSERT INTO projet.etudiants (nom, prenom, email, mdp) VALUES (nom, prenom, email, mdp);
end;
$$ LANGUAGE plpgsql;

-- valider une ue pour un etudiant (etape 4)--
CREATE OR REPLACE FUNCTION projet.encoderUeValidee(ue_code VARCHAR, etudiant_email VARCHAR) RETURNS void AS $$
DECLARE
ue_id INTEGER;
    etudiant_id INTEGER;
BEGIN
SELECT e.id_etudiant FROM projet.etudiants e WHERE e.email = etudiant_email INTO etudiant_id;
SELECT u.id_ue FROM projet.ues u WHERE u.code = ue_code INTO ue_id;
INSERT INTO projet.ues_reussies VALUES (ue_id, etudiant_id);
end;
$$ LANGUAGE plpgsql;


-- afficher etudiants d'un bloc (etape 5) --
CREATE OR REPLACE FUNCTION projet.visualiserEtudiantsDUnBloc(num_bloc INTEGER) RETURNS SETOF RECORD AS $$
DECLARE
etudiant RECORD;
    sortie RECORD;
BEGIN
    IF num_bloc > 3 OR num_bloc < 1 THEN
        RAISE 'Le bloc entré n''est pas valide';
end if;
for etudiant IN SELECT e.nom, e.prenom, p.nb_credits_pae FROM projet.etudiants e, projet.paes p WHERE e.bloc = num_bloc AND p.id_etudiant = e.id_etudiant ORDER BY e.nom, e.prenom LOOP
SELECT etudiant.nom, etudiant.prenom, etudiant.nb_credits_pae INTO sortie;
RETURN next sortie;
end loop;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- afficher etudiants avec nombre credits pae (etape 6) --
CREATE OR REPLACE FUNCTION projet.visualiserEtudiantsAvecLeurPae() RETURNS SETOF RECORD AS $$
DECLARE
etudiants RECORD;
    sortie RECORD;
BEGIN
for etudiants IN SELECT e.nom, e.prenom, e.bloc, p.nb_credits_pae FROM projet.etudiants e, projet.paes p WHERE p.id_etudiant = e.id_etudiant ORDER BY p.nb_credits_pae DESC LOOP
SELECT etudiants.nom, etudiants.prenom, etudiants.bloc, etudiants.nb_credits_pae INTO sortie;
RETURN next sortie;
end loop;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- visualiser les etudiants avec un pae non validée (etape 7) --
CREATE OR REPLACE FUNCTION projet.visualiserEtudiantsPaeNonValide() RETURNS SETOF RECORD AS $$
DECLARE
etudiant RECORD;
    sortie RECORD;
BEGIN
for etudiant IN SELECT e.nom, e.prenom, e.nb_credits_acquis FROM projet.etudiants e, projet.paes p WHERE p.id_etudiant = e.id_etudiant AND p.valide = false ORDER BY e.nom, e.prenom LOOP
SELECT etudiant.nom, etudiant.prenom, etudiant.nb_credits_acquis INTO sortie;
RETURN next sortie;
end loop;
    RETURN;
END;
$$ LANGUAGE plpgsql;



-- visualiser les ues d'un bloc particulier (etape 8) --
CREATE OR REPLACE FUNCTION projet.visualiserUesDUnBloc(num_bloc INTEGER) RETURNS SETOF RECORD AS $$
DECLARE
cours RECORD;
    sortie RECORD;
BEGIN
    IF num_bloc > 3 OR num_bloc < 1 THEN
        RAISE 'Le bloc entré n''est pas valide';
end if;
for cours IN SELECT ues.code, ues.nom, ues.nb_inscrits FROM projet.ues ues WHERE ues.bloc = num_bloc LOOP
SELECT cours.code, cours.nom, cours.nb_inscrits INTO sortie;
RETURN next sortie;
end loop;
    RETURN;
END;
$$ LANGUAGE plpgsql;



-----------------------------------------------
-- DEBUT DES PROCEDURES APPLICATION ETUDIANT --
-----------------------------------------------

-- ajouter une ue au pae d'un etudiant (etape 1)--
CREATE OR REPLACE FUNCTION projet.ajouterUeASonPae(email_etudiant VARCHAR(100), code_ue VARCHAR(20)) RETURNS void AS $$
DECLARE
pae_id INTEGER;
    ue_id INTEGER;
BEGIN
    --verifie que l'UE existe
    IF NOT EXISTS(SELECT * FROM projet.ues ue
                  WHERE ue.code=code_ue) THEN
        RAISE 'Le code de l''UE entré n''est pas valide';
END IF;
SELECT p.id_pae FROM projet.paes p,projet.etudiants e WHERE p.id_etudiant=e.id_etudiant AND e.email=email_etudiant INTO pae_id;
SELECT u.id_ue FROM projet.ues u WHERE u.code=code_ue INTO ue_id;
INSERT INTO projet.lignes_pae (id_pae, id_ue) VALUES (pae_id, ue_id);
END;
$$ LANGUAGE plpgsql;


-- supprimer une ue d'un pae (etape 2) --
CREATE OR REPLACE FUNCTION projet.enleverUeDunPae(email_etudiant VARCHAR(100),code_ue VARCHAR(20)) RETURNS INTEGER AS $$
DECLARE
id_pae_a_supprimer INTEGER;
    id_ue_a_supprimer INTEGER;
BEGIN
SELECT p.id_pae FROM projet.paes p,projet.etudiants e WHERE p.id_etudiant=e.id_etudiant AND e.email=email_etudiant INTO id_pae_a_supprimer;

--verifie que l'UE existe
IF NOT EXISTS(SELECT * FROM projet.ues ue
                  WHERE ue.code=code_ue) THEN
        RAISE 'Cette UE n existe pas';
END IF;
SELECT u.id_ue FROM projet.ues u WHERE u.code=code_ue INTO id_ue_a_supprimer;

--verifie que l'UE se trouvait bien dans le PAE
IF NOT EXISTS(SELECT * FROM projet.lignes_pae lp
                  WHERE lp.id_ue=id_ue_a_supprimer AND lp.id_pae=id_pae_a_supprimer) THEN
        RAISE 'Cette UE ne se trouve pas dans le PAE demandée';
END IF;
DELETE FROM projet.lignes_pae lp WHERE lp.id_pae=id_pae_a_supprimer AND lp.id_ue=id_ue_a_supprimer;
RETURN id_pae_a_supprimer;
END
$$ LANGUAGE plpgsql;


-- valider le pae d'un etudiant (etape 3)--
CREATE OR REPLACE FUNCTION projet.validerSonPae(email_etudiant VARCHAR(100)) RETURNS BOOL AS $$ -- point 3 app étudiant
DECLARE
nb_cred_acquis INTEGER;
    nb_cred_pae INTEGER;
    pae_id INTEGER;
    nv_nb_inscrits INTEGER;
    nv_bloc INTEGER;
    cours RECORD;
    etudiant_id INTEGER;
    valide BOOL;
BEGIN
    valide = false;
SELECT e.id_etudiant, e.nb_credits_acquis FROM projet.etudiants e WHERE e.email=email_etudiant INTO etudiant_id, nb_cred_acquis;
SELECT p.nb_credits_pae, p.id_pae FROM projet.paes p WHERE etudiant_id = p.id_etudiant INTO nb_cred_pae, pae_id;
IF (SELECT p.valide FROM projet.paes p,projet.etudiants e WHERE e.id_etudiant=p.id_etudiant AND e.email=email_etudiant) = true THEN
        RAISE 'Le PAE de l etudiant est déjà validé';
ELSIF nb_cred_acquis + nb_cred_pae >= 180 THEN
        IF nb_cred_pae > 74 THEN
            RAISE 'Condition a respecter : nbcredPae <= 74';
ELSE
            valide = true;
END IF;
    ELSIF nb_cred_acquis < 45 THEN
        IF nb_cred_pae > 60 THEN
            RAISE 'Condition a respecter : nbcredPae <= 60';
ELSE
            valide = true;
end if;
    ELSIF nb_cred_pae >= 55 AND nb_cred_pae <= 74 THEN
        valide = true;
    ELSIF NOT valide THEN
        raise 'Condition a respecter : 55 <= nbcredPae <= 74';
end if;

    -- On valide le PAE

UPDATE projet.paes SET valide = true WHERE id_etudiant = etudiant_id;
-- on détermine le bloc et on l'update
IF nb_cred_acquis < 45 THEN
        nv_bloc = 1;
    ELSIF nb_cred_acquis + nb_cred_pae >= 180 THEN
        nv_bloc = 3;
ELSE
        nv_bloc = 2;
end if;
UPDATE projet.etudiants SET bloc = nv_bloc WHERE id_etudiant = etudiant_id;
-- on ajoute +1 nbInscrits à l'UE
FOR cours IN SELECT lp.id_ue FROM projet.lignes_pae lp WHERE lp.id_pae = pae_id LOOP
            nv_nb_inscrits = (SELECT u.nb_inscrits FROM projet.ues u WHERE u.id_ue = cours.id_ue) + 1;
UPDATE projet.ues SET nb_inscrits = nv_nb_inscrits WHERE id_ue = cours.id_ue;
end loop;
RETURN true;
END;
$$ LANGUAGE plpgsql;

-- afficher les UEs que l'etudiant peut ajouter a son PAE (etape 4)--
CREATE OR REPLACE FUNCTION projet.afficherLesUesAjoutables(email_etudiant VARCHAR(100)) RETURNS SETOF RECORD AS $$
DECLARE
ues RECORD;
    sortie RECORD;
    nb_prerequis INTEGER;
    etudiant_id INTEGER;
    estValide BOOL;
BEGIN
SELECT p.valide FROM projet.paes p, projet.etudiants e WHERE p.id_etudiant=e.id_etudiant AND e.email=email_etudiant INTO estValide;
if estValide=true THEN
        raise 'Le PAE a deja été validé et ne peut plus être modifié';
end if;
SELECT e.id_etudiant FROM projet.etudiants e WHERE e.email=email_etudiant INTO etudiant_id;
--si son nombre de credits aquis est inferieur a 30
if (SELECT e.nb_credits_acquis FROM projet.etudiants e WHERE e.id_etudiant=etudiant_id) <30 THEN
        --on prend tout les UE qui sont reussi et ne se trouvent pas déjà dans le PAE de l'etudiant
        for ues IN SELECT ue.code,ue.nom,ue.nb_credits,ue.bloc FROM projet.ues ue WHERE ue.bloc=1 AND ue.id_ue NOT IN ((SELECT uer.id_ue FROM projet.ues_reussies uer WHERE uer.id_etudiant=etudiant_id) UNION (SELECT lp.id_ue FROM projet.lignes_pae lp,projet.paes p WHERE p.id_etudiant=etudiant_id AND lp.id_pae=p.id_pae)) ORDER BY ue.code LOOP
SELECT ues.code, ues.nom, ues.nb_credits, ues.bloc INTO sortie;
RETURN next sortie;
end loop;
        RETURN;
        --si son nombre de credits aquis est superieur ou egal a 30
ELSE
        --on prend toutes les UEs qui sont reussies et ne se trouvent pas déjà dans le PAE de l'etudiant
        for ues IN SELECT ue.id_ue,ue.code,ue.nom,ue.nb_credits,ue.bloc FROM projet.ues ue WHERE ue.id_ue NOT IN ((SELECT uer.id_ue FROM projet.ues_reussies uer WHERE uer.id_etudiant=etudiant_id) UNION (SELECT lp.id_ue FROM projet.lignes_pae lp,projet.paes p WHERE p.id_etudiant=etudiant_id AND lp.id_pae=p.id_pae)) ORDER BY ue.code LOOP
--check si les UEs ont des prerequis
--on stock le nombre de prerequis qu'a l'UE
SELECT count(up.*) FROM projet.ues_prerequis up WHERE up.id_ue_suite = ues.id_ue INTO nb_prerequis;
--s'il en a plus que 0 alors
IF nb_prerequis > 0 THEN
                    --s'il a reussi tous les prerequis alors on les ajoute au record, sinon on ne fait rien
                    IF (SELECT count(up.id_ue_prerequis) FROM projet.ues_prerequis up WHERE up.id_ue_suite = ues.id_ue AND up.id_ue_prerequis IN (SELECT ur.id_ue FROM projet.ues_reussies ur WHERE ur.id_etudiant = etudiant_id))=nb_prerequis THEN
SELECT ues.code, ues.nom, ues.nb_credits, ues.bloc INTO sortie;
RETURN next sortie;
end if;
                    --si l'UE n'a pas de prerequis, on l'ajoute direct dans le record à renvoyer
else
SELECT ues.code, ues.nom, ues.nb_credits, ues.bloc INTO sortie;
RETURN next sortie;
end if;


end loop;
        RETURN;
end if;
END;
$$ LANGUAGE plpgsql;


-- afficher PAE d'un etudiant (etape 5)--
CREATE OR REPLACE FUNCTION projet.visualiserSonPae(email_etudiant VARCHAR(100)) RETURNS SETOF RECORD AS $$
DECLARE
lignes_du_pae RECORD;
    sortie RECORD;
    _id_pae INTEGER;
BEGIN
SELECT e.id_etudiant FROM projet.etudiants e,projet.paes p WHERE e.email=email_etudiant AND p.id_etudiant=e.id_etudiant INTO _id_pae;
--le PAE est déjà vide
IF NOT EXISTS(SELECT p.id_pae FROM projet.paes p,projet.lignes_pae lp
                  WHERE p.id_pae=_id_pae AND lp.id_pae=p.id_pae
                  GROUP BY p.id_pae
                  HAVING count(lp.*)>=1) THEN
        RAISE 'La PAE est vide';
END IF;
for lignes_du_pae IN SELECT ues.code, ues.nom, ues.nb_credits, ues.bloc FROM projet.paes p, projet.lignes_pae lp, projet.ues ues WHERE p.id_pae = _id_pae AND p.id_pae = lp.id_pae AND ues.id_ue = lp.id_ue LOOP
SELECT lignes_du_pae.code, lignes_du_pae.nom, lignes_du_pae.nb_credits, lignes_du_pae.bloc INTO sortie;
RETURN next sortie;
end loop;
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- reinitialiser son PAE (etape 6) --
CREATE OR REPLACE FUNCTION projet.reinitialiserSonPae(email_etudiant VARCHAR(100)) RETURNS void AS $$
DECLARE
id_pae_a_supprimer INTEGER;
BEGIN
SELECT e.id_etudiant FROM projet.etudiants e,projet.paes p WHERE e.email=email_etudiant AND p.id_etudiant=e.id_etudiant INTO id_pae_a_supprimer;
--le PAE est déjà vide
IF NOT EXISTS(SELECT p.id_pae FROM projet.paes p,projet.lignes_pae lp
                  WHERE p.id_pae=id_pae_a_supprimer AND lp.id_pae=p.id_pae
                  GROUP BY p.id_pae
                  HAVING count(lp.*)>=1) THEN
        RAISE 'La PAE est vide';
END IF;
DELETE FROM projet.lignes_pae lp WHERE lp.id_pae=id_pae_a_supprimer;
RETURN;
END
$$ LANGUAGE plpgsql;


-- recuperer le mot de passe d'un etudiant
CREATE OR REPLACE FUNCTION projet.recupererMdpEtudiant (email_etudiant VARCHAR(100)) RETURNS CHAR(60) AS $$
DECLARE
mot_de_passe CHAR(60);
BEGIN
    --si l'etudiant n'existe pas
    IF NOT EXISTS(SELECT e.* FROM projet.etudiants e WHERE e.email=email_etudiant) THEN
        RAISE 'etudiant inexistant';
END IF;
SELECT e.mdp FROM projet.etudiants e WHERE e.email=email_etudiant INTO mot_de_passe;
-- on renvoie le mdp
RETURN mot_de_passe;
END
$$ LANGUAGE plpgsql;

GRANT CONNECT ON DATABASE dbnicolaspoppe TO stefanmircovici;
GRANT USAGE ON SCHEMA projet TO stefanmircovici;

GRANT SELECT ON projet.etudiants, projet.paes, projet.ues, projet.lignes_pae, projet.ues_prerequis, projet.ues_reussies TO stefanmircovici ;

GRANT INSERT ON TABLE projet.lignes_pae TO stefanmircovici ;

GRANT UPDATE ON TABLE projet.paes, projet.etudiants, projet.ues TO stefanmircovici;
GRANT DELETE ON TABLE projet.lignes_pae  TO stefanmircovici;