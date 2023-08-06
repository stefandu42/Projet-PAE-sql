-- supprimer une ue d'une pae (etape 2) --
CREATE OR REPLACE FUNCTION projet.enleverUeDunPae(email_etudiant VARCHAR(100),code_ue VARCHAR(20)) RETURNS INTEGER AS $$
    DECLARE
        id_pae_a_supprimer INTEGER;
        id_ue_a_supprimer INTEGER;
    BEGIN
       --verifie que l'etudiant existe
       IF NOT EXISTS(SELECT * FROM projet.etudiants e
                WHERE e.email=email_etudiant) THEN
                RAISE 'Cet etudiant n existe pas';
        END IF;
        SELECT p.id_pae FROM projet.paes p,projet.etudiants e WHERE p.id_etudiant=e.id_etudiant AND e.email=email_etudiant INTO id_pae_a_supprimer;

        --verifie que le UE existe
        IF NOT EXISTS(SELECT * FROM projet.ues ue
                WHERE ue.code=code_ue) THEN
                RAISE 'Cette UE n existe pas';
        END IF;
        SELECT u.id_ue FROM projet.ues u WHERE u.code=code_ue INTO id_ue_a_supprimer;


        DELETE FROM projet.lignes_pae lp WHERE lp.id_pae=id_pae_a_supprimer AND lp.id_ue=id_ue_a_supprimer;
        RETURN id_pae_a_supprimer;
    END
$$ LANGUAGE plpgsql;