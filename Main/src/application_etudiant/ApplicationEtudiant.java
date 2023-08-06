package application_etudiant;

import java.sql.*;
import java.util.Scanner;

public class ApplicationEtudiant {
    private Connection conn;
    private Scanner sc = new Scanner(System.in);
    private PreparedStatement psAjouterUeAuPae;
    private PreparedStatement psEnleverUeAuPae;
    private PreparedStatement psValiderSonPae;
    private PreparedStatement psAfficherUesAffichables;
    private PreparedStatement psvisualiserSonPae;
    private PreparedStatement psReinitialiserSonPae;
    private PreparedStatement psRecupererMdpEtudiant;
    private String emailEtudiant;

    public ApplicationEtudiant(){
        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            System.out.println("Driver PostgreSQL manquant !");
            System.exit(1);
        }
        // connection
        String url="jdbc:postgresql://172.24.2.6:5432/dbnicolaspoppe";
        this.conn=null;
        try {
            this.conn= DriverManager.getConnection(url,"stefanmircovici","E5NCIP0JD");
            //this.conn = DriverManager.getConnection(url,"postgres","");
        } catch (SQLException e) {
            e.printStackTrace();
            System.out.println("Impossible de joindre le server !");
            System.exit(1);
        }
        try {
            // On prépare toutes les requêtes
            this.psAjouterUeAuPae = conn.prepareStatement("SELECT projet.ajouterUeASonPae(?,?);");
            this.psEnleverUeAuPae = conn.prepareStatement("SELECT projet.enleverUeDunPae(?,?);");
            this.psValiderSonPae = conn.prepareStatement("SELECT projet.validerSonPae(?);");
            this.psAfficherUesAffichables = conn.prepareStatement("SELECT * FROM projet.afficherLesUesAjoutables(?) AS t(code VARCHAR(20),nom VARCHAR(100), nb_credits INTEGER,bloc INTEGER);");
            this.psvisualiserSonPae = conn.prepareStatement("SELECT * FROM projet.visualiserSonPae(?) AS t(code VARCHAR(20),nom VARCHAR(100), nb_credits INTEGER,bloc INTEGER);");
            this.psReinitialiserSonPae = conn.prepareStatement("SELECT projet.reinitialiserSonPae(?);");
            this.psRecupererMdpEtudiant = conn.prepareStatement("SELECT projet.recupererMdpEtudiant(?);");
        } catch (SQLException e) {
            e.printStackTrace();
        }
        // L'étudiant doit se connecter
        boolean connecte = false;
        while(!connecte){
            System.out.println("Veuillez vous connecter !\n");
            System.out.print("Entrez votre email : ");
            String emailEtudiant = sc.nextLine();
            System.out.print("Entrez votre mot de passe : ");
            String mdp = sc.nextLine();
            try {
                this.psRecupererMdpEtudiant.setString(1,emailEtudiant);
                this.psRecupererMdpEtudiant.executeQuery();
                try(ResultSet rs= this.psRecupererMdpEtudiant.executeQuery()){
                    rs.next();
                    String mdpDeLaDb = rs.getString(1);
                    if(!BCrypt.checkpw(mdp, mdpDeLaDb)){
                        System.out.println("Mot de passe incorrecte.");
                    }
                    else{
                        connecte = true;
                        this.emailEtudiant=emailEtudiant;
                    }
                }
            } catch (SQLException e) {
                System.out.println(e.getMessage());
            }
        }
        menu();
    }

    /**
     * Affichage du menu montrant toutes les actions que l'utilisateur peut effectuer
     */
    public void menu(){
        while(true){
            System.out.println("Bienvenue dans l'application etudiant.");
            System.out.println("1. Ajouter une UE à son PAE");
            System.out.println("2. Enlever une UE à son PAE");
            System.out.println("3. Valider son PAE");
            System.out.println("4. Afficher les UEs que l'etudiant peut ajouter à son PAE");
            System.out.println("5. Visualiser son PAE");
            System.out.println("6. Reinitialiser son PAE");
            System.out.println("0. Sortir de l'application");
            System.out.print("Que voulez-vous faire? ");
            int i = sc.nextInt();
            switch (i) {
                case 0:
                    System.out.println("Fin de l'application !");
                    return;
                case 1:
                    ajouterUeASonPae();
                    break;
                case 2:
                    enleverUeDunPae();
                    break;
                case 3:
                    validerSonPae();
                    break;
                case 4:
                    afficherLesUesAjoutables();
                    break;
                case 5:
                    visualiserSonPae();
                    break;
                case 6:
                    reinitialiserSonPae();
                    break;
                default:
                    System.out.println("Entrez un nombre valide !\n");
                    break;
            }
            System.out.print("\n");
        }
    }

    /**
     * Ajouter une UE au PAE de l'étudiant connecté
     */
    public void ajouterUeASonPae(){
        System.out.print("Veuillez entrer le code de l'ue : ");
        sc.nextLine();
        String codeUe = sc.nextLine();
        try {
            psAjouterUeAuPae.setString(1,this.emailEtudiant);
            psAjouterUeAuPae.setString(2,codeUe);
            psAjouterUeAuPae.executeQuery();
            System.out.println("L'UE "+codeUe+" a été ajouté à votre PAE");
        } catch (SQLException se) {
            System.out.println(se.getMessage());
        }
    }

    /**
     * Supprimer une UE du PAE de l'étudiant connecté
     */
    public void enleverUeDunPae(){
        System.out.print("Veuillez entrer le code de l'ue : ");
        sc.nextLine();
        String codeUe = sc.nextLine();
        try {
            psEnleverUeAuPae.setString(1,this.emailEtudiant);
            psEnleverUeAuPae.setString(2,codeUe);
            psEnleverUeAuPae.executeQuery();
            System.out.println("L'UE "+codeUe+" a été enlevé de votre PAE\n");
        } catch (SQLException se) {
            System.out.println(se.getMessage());
        }
    }

    /**
     * Valider le PAE de l'étudiant connecté
     */
    public void validerSonPae(){
        try {
            psValiderSonPae.setString(1,this.emailEtudiant);
            psValiderSonPae.executeQuery();
            System.out.println("Votre PAE a été validé\n");
        } catch (SQLException se) {
            System.out.println(se.getMessage());
        }
    }

    /**
     * Afficher toutes les UEs que l'étudiant connecté peut ajouter
     */
    public void afficherLesUesAjoutables(){
        try {
            psAfficherUesAffichables.setString(1,this.emailEtudiant);
            try(ResultSet rs= psAfficherUesAffichables.executeQuery()){
                System.out.println("Les UEs ajoutables : ");
                while(rs.next()) {
                    System.out.println("Code UE : "+rs.getString(1)+" | Nom UE : "+rs.getString(2)+" | Nombre de credits : "+rs.getInt(3)+" | Bloc : "+rs.getInt(4));
                }
            }
        } catch (SQLException se) {
            System.out.println(se.getMessage());
        }
    }

    /**
     * Voir le PAE de l'étudiant connecté
     */
    public void visualiserSonPae(){
        try {
            psvisualiserSonPae.setString(1,this.emailEtudiant);
            try(ResultSet rs= psvisualiserSonPae.executeQuery()){
                while(rs.next()) {
                    System.out.println("Code UE : "+rs.getString(1)+" | Nom UE : "+rs.getString(2)+" | Nombre de credits : "+rs.getInt(3)+" | Bloc : "+rs.getInt(4));
                }
            }
        } catch (SQLException se) {
            System.out.println(se.getMessage());

        }
    }

    /**
     * Reinitialiser le PAE de l'étudiant connecté
     */
    public void reinitialiserSonPae(){
        try {
            psReinitialiserSonPae.setString(1,this.emailEtudiant);
            psReinitialiserSonPae.executeQuery();
            System.out.println("Votre PAE a été réinitialisé\n");
        } catch (SQLException se) {
            System.out.println(se.getMessage());
            System.out.println("Votre PAE n'a donc pas été réinitialisé");
        }
    }
}
