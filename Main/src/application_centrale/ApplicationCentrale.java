package application_centrale;

import java.sql.*;
import java.util.Scanner;

public class ApplicationCentrale {
    private Connection conn;
    private Scanner sc = new Scanner(System.in);
    private PreparedStatement psAjouterEtudiant;
    private PreparedStatement psAjouterUe;
    private PreparedStatement psAjouterUePrerequis;
    private PreparedStatement psEncoderUeValidee;
    private PreparedStatement psVisualiserEtudiantsParBloc;
    private PreparedStatement psVisualiserEtudiantsNbCredPae;
    private PreparedStatement psVisualiserEtudiantsPaeNonValide;
    private PreparedStatement psVisualiserUesDUnBloc;

    public ApplicationCentrale() {
        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            System.out.println("Driver PostgreSQL manquant !");
            System.exit(1);
        }
        // connection
        String url = "jdbc:postgresql://172.24.2.6:5432/dbnicolaspoppe";
        this.conn = null;
        try {
            this.conn = DriverManager.getConnection(url, "nicolaspoppe", "1VG09FZ8T");
        } catch (SQLException e) {
            e.printStackTrace();
            System.out.println("Impossible de joindre le server !");
            System.exit(1);
        }
        try {
            // On prépare toutes les requêtes
            this.psAjouterUe = conn.prepareStatement("SELECT projet.ajouterUe(?,?,?,?);");
            this.psAjouterUePrerequis = conn.prepareStatement("SELECT projet.ajouterUePrerequis(?,?);");
            this.psAjouterEtudiant = conn.prepareStatement("SELECT projet.ajouterEtudiant(?,?,?,?);");
            this.psEncoderUeValidee = conn.prepareStatement("SELECT projet.encoderUeValidee(?,?);");
            this.psVisualiserEtudiantsParBloc = conn.prepareStatement("SELECT * FROM projet.visualiserEtudiantsDUnBloc(?) as t (nom varchar(100), prenom varchar(100), nombre_credits_pae integer);");
            this.psVisualiserEtudiantsNbCredPae = conn.prepareStatement("SELECT * FROM projet.visualiserEtudiantsAvecLeurPae() as t (nom varchar(100), prenom varchar(100), bloc integer, nombre_credits_pae integer)");
            this.psVisualiserEtudiantsPaeNonValide = conn.prepareStatement("SELECT * FROM projet.visualiserEtudiantsPaeNonValide() as t (nom varchar(100), prenom varchar(100), nombre_credits_acquis integer);");
            this.psVisualiserUesDUnBloc = conn.prepareStatement("SELECT * FROM projet.visualiserUesDUnBloc(?) as t (code varchar(20), nom varchar(100), nombre_inscrits integer)");
        } catch (SQLException e) {
            e.printStackTrace();
        }
        menu();
    }

    /**
     * Affichage du menu montrant toutes les actions que l'utilisateur peut effectuer
     */
    public void menu() {
        int i;
        while (true) {
            System.out.println("Bienvenue dans l'application centrale.");
            System.out.println("Que voulez-vous faire?");
            System.out.println("1. Ajouter une UE");
            System.out.println("2. Ajouter un prérequis à une UE");
            System.out.println("3. Ajouter un étudiant");
            System.out.println("4. Encoder une UE validée pour un étudiant");
            System.out.println("5. Visualiser tous les étudiants d'un bloc particulier");
            System.out.println("6. Visualiser, pour tous les étudiants, le nombre de crédits du PAE");
            System.out.println("7. Visualiser tous les étudiants qui n'ont pas encore validé leur PAE");
            System.out.println("8. Visualiser toutes les UEs d'un bloc particulier");
            System.out.println("0. Sortir de l'application");
            System.out.print("Que voulez-vous faire? ");
            i = sc.nextInt();
            switch (i) {
                case 0:
                    System.out.println("Fin de l'application !");
                    return;
                case 1:
                    ajouterUE();
                    break;
                case 2:
                    ajouterUePrerequis();
                    break;
                case 3:
                    ajouterEtudiant();
                    break;
                case 4:
                    encoderUeValidee();
                    break;
                case 5:
                    visualiserEtudiantsParBloc();
                    break;
                case 6:
                    visualiserEtudiantsNbCredPae();
                    break;
                case 7:
                    visualiserEtudiantsPaeNonValide();
                    break;
                case 8:
                    visualiserUesDUnBloc();
                    break;
                default:
                    System.out.println("Veuillez entrer un numéro valable");
                    break;
            }
            System.out.print("\n");
        }
    }

    /**
     * Ajouter une nouvelle UE dans la base de données si les champs entrés sont corrects
     */
    public void ajouterUE() {
        System.out.print("Veuillez entrer le code de l'ue: ");
        sc.nextLine();
        String codeUe = sc.nextLine();
        System.out.print("Veuillez entrer le nom de l'ue : ");
        String nomUe = sc.nextLine();
        System.out.print("Veuillez entrer le bloc de l'ue : ");
        int bloc = sc.nextInt();
        System.out.print("Veuillez entrer le nombre de crédits de ce cours : ");
        int nbCred = sc.nextInt();
        try {
            this.psAjouterUe.setString(1, codeUe);
            this.psAjouterUe.setString(2, nomUe);
            this.psAjouterUe.setInt(3, bloc);
            this.psAjouterUe.setInt(4, nbCred);
            this.psAjouterUe.executeQuery();
            System.out.println("L'UE " + codeUe + " : " + nomUe + " a bien été ajoutée.");
        } catch (SQLException se) {
            //Gestion des erreurs
            System.out.println(se.getMessage());
            System.out.println("L'ajout de l'UE a donc échoué");
        }
    }

    /**
     * Ajouter un prérequis à une UE si les UEs entrées sont corrects
     */
    public void ajouterUePrerequis() {
        System.out.print("Veuillez entrer le code du cours qui a besoin d'un prerequis : ");
        sc.nextLine();
        String codeUe = sc.nextLine();
        System.out.print("Veuillez entrer le code du cours qui est le prérequis : ");
        String codePrerequis = sc.nextLine();
        try {
            this.psAjouterUePrerequis.setString(1, codePrerequis);
            this.psAjouterUePrerequis.setString(2, codeUe);
            this.psAjouterUePrerequis.executeQuery();
            System.out.println("L'Ue " + codePrerequis + " est devenu un cours prérequis de l'UE " + codeUe);
        } catch (SQLException se) {
            //Gestion des erreurs
            System.out.println(se.getMessage());
            System.out.println("L'ajout du prérequis a donc échoué");
        }
    }

    /**
     * Ajouter un étudiant dans la base de données si il n'existe pas déjà
     */
    public void ajouterEtudiant() {
        System.out.print("Veuillez entrer le nom de l'étudiant : ");
        sc.nextLine();
        String nom = sc.nextLine();
        System.out.print("Veuillez entrer le prénom de l'étudiant : ");
        String prenom = sc.nextLine();
        System.out.print("Veuillez entrer l'email de l'étudiant : ");
        String email = sc.nextLine();
        System.out.print("Veuillez entrer le mot de passe de l'étudiant : ");
        String mdp = sc.nextLine();
        String sel = BCrypt.gensalt();
        mdp = BCrypt.hashpw(mdp, sel);
        try {
            this.psAjouterEtudiant.setString(1, nom);
            this.psAjouterEtudiant.setString(2, prenom);
            this.psAjouterEtudiant.setString(3, email);
            this.psAjouterEtudiant.setString(4, mdp);
            this.psAjouterEtudiant.executeQuery();
            System.out.println("L'étudiant " + nom + " " + prenom + " avec l'adresse email : " + email+ " a bien été ajouté");
        } catch (SQLException se) {
            //Gestion des erreurs
            System.out.println(se.getMessage());
            System.out.println("L'ajout de l'étudiant a donc échoué");
        }
    }

    /**
     * Ajouter une UE validée à un étudiant
     */
    public void encoderUeValidee() {
        System.out.print("Veuillez entrer le code de l'Ue : ");
        sc.nextLine();
        String ueCode = sc.nextLine();
        System.out.print("Veuillez entrer l'email de l'étudiant : ");
        String email = sc.nextLine();
        try {
            this.psEncoderUeValidee.setString(1, ueCode);
            this.psEncoderUeValidee.setString(2, email);
            this.psEncoderUeValidee.executeQuery();
            System.out.println("Validation de l'UE " + ueCode + " pour l'étudiant qui a pour adresse email " + email);
        } catch (SQLException se) {
            //Gestion des erreurs
            System.out.println(se.getMessage());
            System.out.println("La validation de l'UE a donc échouée");
        }
    }

    /**
     * Affiche tous les étudiants d'un certain bloc
     */
    public void visualiserEtudiantsParBloc() {
        System.out.print("Veuillez entrer le bloc : ");
        int bloc = sc.nextInt();
        try {
            this.psVisualiserEtudiantsParBloc.setInt(1, bloc);
            ResultSet rs = this.psVisualiserEtudiantsParBloc.executeQuery();
            System.out.println("Étudiants du bloc " + bloc + " : ");
            boolean suivant = rs.next();
            if (!suivant) {
                System.out.println("Aucun élève dans ce bloc");
            } else {
                affichage(rs, suivant);
            }
        } catch (SQLException se) {
            //Gestion des erreurs
            System.out.println(se.getMessage());
        }
    }

    /**
     * Affiche tous les étudiants avec le nombre de crédits de leur PAE
     */
    public void visualiserEtudiantsNbCredPae() {
        try {
            ResultSet rs = this.psVisualiserEtudiantsNbCredPae.executeQuery();
            System.out.println("Étudiants : ");
            boolean suivant = rs.next();
            if (!suivant) {
                System.out.println("Aucun élève n'est enregistré");
            } else {
                affichage(rs, suivant);
            }
        } catch (SQLException se) {
            System.out.println(se.getMessage());
        }
    }

    /**
     * Affiche tous les étudiants qui ont un PAE qui n'est pas encore validé
     */
    public void visualiserEtudiantsPaeNonValide() {
        try {
            ResultSet rs = this.psVisualiserEtudiantsPaeNonValide.executeQuery();
            System.out.println("Étudiants : ");
            boolean suivant = rs.next();
            if (!suivant) {
                System.out.println("Aucun élève n'est enregistré");
            } else {
                affichage(rs, suivant);
            }
        } catch (SQLException se) {
            System.out.println(se.getMessage());
        }
    }

    /**
     * Affiche toutes les UEs d'un bloc particulier
     */
    public void visualiserUesDUnBloc() {
        System.out.print("Veuillez entrer le bloc : ");
        int bloc = sc.nextInt();
        try {
            this.psVisualiserUesDUnBloc.setInt(1, bloc);
            ResultSet rs = this.psVisualiserUesDUnBloc.executeQuery();
            System.out.println("Ues du bloc " + bloc + " : ");
            boolean suivant = rs.next();
            if (!suivant) {
                System.out.println("Aucune Ues pour ce bloc");
            } else {
                affichage(rs, suivant);
            }
        } catch (SQLException se) {
            //Gestion des erreurs
            System.out.println(se.getMessage());
        }

    }

    /**
     * Affiche le résultat d'une requête
     * @param rs : contenant le résultat de la requête
     * @param suivant : true si il y a un suivant sinon false
     * @throws SQLException
     */
    private void affichage(ResultSet rs, boolean suivant) throws SQLException {
        String message;
        while (suivant) {
            for (int i = 1; i <= rs.getMetaData().getColumnCount(); i++) {
                // On modifie le nom de la colonne pour qu'elle soit compréhensible
                message = rs.getMetaData().getColumnName(i).replace('_', ' ');
                message = message.substring(0, 1).toUpperCase() + message.substring(1);
                System.out.print(message + " : ");
                // On affiche la donnée obtenu dans le tuple
                message = rs.getString(i);
                // On change les null en indéterminé pour que l'utilisateur comprenne
                if (message == null) {
                    message = "indéterminé";
                }
                System.out.print(message + " \n");
            }
            suivant = rs.next();
            System.out.print("\n");
        }
    }
}
