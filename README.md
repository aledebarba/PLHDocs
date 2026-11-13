# SIGEC – Sistema de Gestão de Espaços Comuns

O **SIGEC** é uma plataforma desenvolvida em Dart/Flutter para centralizar e automatizar o processo de consulta, solicitação, aprovação, acompanhamento e cancelamento de reservas dos espaços comuns de um Condomínio.

## 🎯 Objetivo

Substituir o controle atual, feito por planilhas eletrônicas e mensagens de WhatsApp, oferecendo aos moradores um canal único e organizado para reserva dos espaços de lazer e convivência, e à administração um mecanismo automatizado de verificação de regras, disponibilidade e aprovação.

## 📋 Documentação e Regras

Para manter este README conciso, a documentação detalhada foi dividida em arquivos específicos:

- [**Requisitos do Sistema**](doc/requirements.md): Lista completa de Requisitos Funcionais (RF) e Não Funcionais (RNF).
- [**Regras de Domínio**](doc/domain_rules.md): Regras de negócio, prazos e restrições para reservas.

## 👥 Perfis de Usuário

- **Morador:** Consulta espaços comuns, verifica disponibilidade e regras, solicita reservas, acompanha o status e realiza cancelamentos.
- **Administrador:** Gerencia o cadastro de moradores e espaços, analisa e aprova solicitações, e configura regras de utilização.

## 🏗️ Espaços Abrangidos

O sistema gerencia os seguintes espaços:

- Salão de festas
- Churrasqueira
- Salão gourmet
- Quadra esportiva
- Espaço kids
- Academia

---

## 🚀 Como Começar

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-started)

### Instalação

1. Clone o repositório.
2. Execute `flutter pub get` para instalar as dependências.
3. Execute o projeto com `flutter run`.

---

_Este projeto é uma solução para modernização da gestão condominial._
