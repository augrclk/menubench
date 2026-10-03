// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

struct SecurityFeatureStrings {
    let importedScriptDisabled: String
    let reviewScriptTitle: String
    let reviewScriptBodyFormat: String
    let allowScript: String
    let manualUpdateTitle: String
    let manualUpdateBody: String

    static func forLanguage(_ language: AppLanguage) -> Self {
        switch language {
        case .enUS:
            return Self(
                importedScriptDisabled: "Imported script — approval required",
                reviewScriptTitle: "Allow this imported script?",
                reviewScriptBodyFormat: "Review this executable before enabling it:\n\n%@\n\nIt will run with your permissions when you pause typing its name in Command Bar. Enable only if you trust its contents.",
                allowScript: "Allow script",
                manualUpdateTitle: "Update manually",
                manualUpdateBody: "Automatic updates with administrator privileges require Menubench in /Applications. Download the signed DMG from github.com/augrclk/menubench/releases and replace the app manually, or move it to /Applications.")
        case .tr:
            return Self(
                importedScriptDisabled: "İçe aktarılan script — onay gerekli",
                reviewScriptTitle: "İçe aktarılan script’e izin verilsin mi?",
                reviewScriptBodyFormat: "Etkinleştirmeden önce bu çalıştırılabilir dosyayı inceleyin:\n\n%@\n\nKomut Çubuğu’nda adını yazmaya ara verdiğinizde sizin yetkilerinizle çalışır. Yalnızca içeriğine güveniyorsanız etkinleştirin.",
                allowScript: "Script’e izin ver",
                manualUpdateTitle: "Manuel güncelleyin",
                manualUpdateBody: "Yönetici yetkisiyle otomatik güncelleme için Menubench /Applications klasöründe olmalı. github.com/augrclk/menubench/releases adresinden imzalı DMG’yi indirip uygulamayı manuel değiştirin veya /Applications klasörüne taşıyın.")
        case .ptBR:
            return Self(
                importedScriptDisabled: "Script importado — aprovação necessária",
                reviewScriptTitle: "Permitir este script importado?",
                reviewScriptBodyFormat: "Revise este executável antes de ativá-lo:\n\n%@\n\nEle será executado com suas permissões quando você pausar a digitação do nome na Barra de Comandos. Ative somente se confiar no conteúdo.",
                allowScript: "Permitir script",
                manualUpdateTitle: "Atualizar manualmente",
                manualUpdateBody: "Atualizações automáticas com privilégios de administrador exigem o Menubench em /Applications. Baixe o DMG assinado em github.com/augrclk/menubench/releases e substitua o app manualmente ou mova-o para /Applications.")
        case .ru:
            return Self(
                importedScriptDisabled: "Импортированный скрипт — требуется разрешение",
                reviewScriptTitle: "Разрешить импортированный скрипт?",
                reviewScriptBodyFormat: "Проверьте исполняемый файл перед включением:\n\n%@\n\nОн запускается с вашими правами при паузе ввода его имени в панели команд. Включайте только если доверяете содержимому.",
                allowScript: "Разрешить скрипт",
                manualUpdateTitle: "Обновить вручную",
                manualUpdateBody: "Автообновление с правами администратора требует Menubench в /Applications. Загрузите подписанный DMG с github.com/augrclk/menubench/releases и замените приложение вручную либо переместите его в /Applications.")
        case .es:
            return Self(
                importedScriptDisabled: "Script importado — requiere aprobación",
                reviewScriptTitle: "¿Permitir este script importado?",
                reviewScriptBodyFormat: "Revisa este ejecutable antes de activarlo:\n\n%@\n\nSe ejecutará con tus permisos cuando pauses al escribir su nombre en la barra de comandos. Actívalo solo si confías en su contenido.",
                allowScript: "Permitir script",
                manualUpdateTitle: "Actualizar manualmente",
                manualUpdateBody: "Las actualizaciones automáticas con permisos de administrador requieren Menubench en /Applications. Descarga el DMG firmado desde github.com/augrclk/menubench/releases y reemplaza la app manualmente o muévela a /Applications.")
        case .de:
            return Self(
                importedScriptDisabled: "Importiertes Skript — Freigabe erforderlich",
                reviewScriptTitle: "Importiertes Skript erlauben?",
                reviewScriptBodyFormat: "Prüfe diese ausführbare Datei vor dem Aktivieren:\n\n%@\n\nSie läuft mit deinen Rechten, wenn du beim Eingeben ihres Namens in der Befehlsleiste pausierst. Aktiviere sie nur, wenn du dem Inhalt vertraust.",
                allowScript: "Skript erlauben",
                manualUpdateTitle: "Manuell aktualisieren",
                manualUpdateBody: "Automatische Updates mit Administratorrechten benötigen Menubench in /Applications. Lade das signierte DMG von github.com/augrclk/menubench/releases und ersetze die App manuell oder verschiebe sie nach /Applications.")
        case .fr:
            return Self(
                importedScriptDisabled: "Script importé — autorisation requise",
                reviewScriptTitle: "Autoriser ce script importé ?",
                reviewScriptBodyFormat: "Vérifiez cet exécutable avant de l’activer :\n\n%@\n\nIl s’exécute avec vos droits lorsque vous faites une pause en saisissant son nom dans la barre de commandes. Activez-le uniquement si vous faites confiance à son contenu.",
                allowScript: "Autoriser le script",
                manualUpdateTitle: "Mettre à jour manuellement",
                manualUpdateBody: "Les mises à jour avec des droits administrateur exigent Menubench dans /Applications. Téléchargez le DMG signé depuis github.com/augrclk/menubench/releases et remplacez l’app manuellement ou déplacez-la dans /Applications.")
        case .it:
            return Self(
                importedScriptDisabled: "Script importato — approvazione richiesta",
                reviewScriptTitle: "Consentire questo script importato?",
                reviewScriptBodyFormat: "Controlla questo eseguibile prima di attivarlo:\n\n%@\n\nVerrà eseguito con i tuoi permessi quando interrompi la digitazione del suo nome nella barra dei comandi. Attivalo solo se ti fidi del contenuto.",
                allowScript: "Consenti script",
                manualUpdateTitle: "Aggiorna manualmente",
                manualUpdateBody: "Gli aggiornamenti automatici con privilegi di amministratore richiedono Menubench in /Applications. Scarica il DMG firmato da github.com/augrclk/menubench/releases e sostituisci l’app manualmente o spostala in /Applications.")
        case .ja:
            return Self(
                importedScriptDisabled: "インポートしたスクリプト — 承認が必要",
                reviewScriptTitle: "このスクリプトを許可しますか？",
                reviewScriptBodyFormat: "有効にする前に実行ファイルを確認してください：\n\n%@\n\nコマンドバーで名前を入力して一時停止すると、あなたの権限で実行されます。内容を信頼できる場合のみ有効にしてください。",
                allowScript: "スクリプトを許可",
                manualUpdateTitle: "手動で更新",
                manualUpdateBody: "管理者権限での自動更新には、Menubench が /Applications にある必要があります。github.com/augrclk/menubench/releases から署名済み DMG をダウンロードして手動で置き換えるか、アプリを /Applications に移動してください。")
        case .ko:
            return Self(
                importedScriptDisabled: "가져온 스크립트 — 승인 필요",
                reviewScriptTitle: "이 스크립트를 허용할까요?",
                reviewScriptBodyFormat: "활성화하기 전에 실행 파일을 검토하세요:\n\n%@\n\n명령 막대에서 이름 입력을 멈추면 사용자 권한으로 실행됩니다. 내용을 신뢰하는 경우에만 활성화하세요.",
                allowScript: "스크립트 허용",
                manualUpdateTitle: "수동 업데이트",
                manualUpdateBody: "관리자 권한으로 자동 업데이트하려면 Menubench가 /Applications에 있어야 합니다. github.com/augrclk/menubench/releases에서 서명된 DMG를 내려받아 앱을 수동으로 교체하거나 /Applications로 옮기세요.")
        case .zhHans:
            return Self(
                importedScriptDisabled: "导入的脚本 — 需要批准",
                reviewScriptTitle: "允许此导入的脚本？",
                reviewScriptBodyFormat: "启用前请检查此可执行文件：\n\n%@\n\n在命令栏中输入其名称并暂停时，它会以您的权限运行。仅在信任其内容时启用。",
                allowScript: "允许脚本",
                manualUpdateTitle: "手动更新",
                manualUpdateBody: "以管理员权限自动更新需要 Menubench 位于 /Applications。请从 github.com/augrclk/menubench/releases 下载已签名的 DMG 并手动替换应用，或将应用移至 /Applications。")
        case .zhTW, .zhHK:
            return Self(
                importedScriptDisabled: "匯入的腳本 — 需要批准",
                reviewScriptTitle: "允許此匯入的腳本？",
                reviewScriptBodyFormat: "啟用前請檢查此執行檔：\n\n%@\n\n在命令列中輸入其名稱並暫停時，它會以您的權限執行。僅在信任其內容時啟用。",
                allowScript: "允許腳本",
                manualUpdateTitle: "手動更新",
                manualUpdateBody: "以管理員權限自動更新需要 Menubench 位於 /Applications。請從 github.com/augrclk/menubench/releases 下載已簽署的 DMG 並手動替換應用程式，或將應用程式移至 /Applications。")
        }
    }
}
