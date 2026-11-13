# Guia de Testes - Validação de ind_habilitado

## Teste 1: Login com Usuário Habilitado

### Pré-requisitos:
- Firestore tem um usuário com `ind_habilitado = 'S'`
- Exemplo: `admin` com `ind_habilitado = 'S'`

### Passos:
1. Abra o app
2. Vá para a tela de Login
3. Insira credenciais do usuário habilitado
   - Usuário: `admin`
   - Senha: (a senha do admin)
4. Clique em "Login"

### Resultado Esperado:
✅ **Login bem-sucedido**
- Acesso à HOME PAGE
- Acesso a todas as funcionalidades

---

## Teste 2: Login com Usuário Desabilitado

### Pré-requisitos:
- Firestore tem um usuário com `ind_habilitado = 'N'`
- Você pode criar um usuário de teste e desabilitá-lo via "Gerenciar Usuários"

### Passos:
1. Abra o app
2. Vá para a tela de Login
3. Insira credenciais de um usuário desabilitado
4. Clique em "Login"

### Resultado Esperado:
❌ **Login bloqueado**
- Mensagem de erro: **`Usuário inválido`**
- Container vermelho exibido no topo da tela
- Usuário permanece na tela de login
- Pode tentar outro usuário

---

## Teste 3: Desabilitar Usuário Enquanto Logado

### Pré-requisitos:
- Você está logado como admin
- Você tem acesso à tela "Gerenciar Usuários"

### Passos:
1. **Passo A (Outra aba/dispositivo):**
   - Abra o app em outro dispositivo/aba
   - Faça login como outro usuário (ex: `user1`)
   - Deixe logado

2. **Passo B (Admin):**
   - Faça login como admin no app principal
   - Vá para "Gerenciar Usuários"
   - Selecione `user1`
   - Clique em "Editar"
   - Mude Status de "Habilitado" para "Desabilitado"
   - Clique em "Salvar"

3. **Passo C (Volta para user1):**
   - No outro dispositivo/aba onde `user1` está logado
   - Deixe o app rodando normalmente
   - Feche o app
   - Reabra o app

### Resultado Esperado:
❌ **Sessão de user1 removida**
- App detecta que usuário foi desabilitado
- Tela de login é exibida
- `user1` é forçado a fazer login novamente
- Tentará fazer login e receberá: **`Usuário inválido`**

---

## Teste 4: Sem Conexão com Internet

### Pré-requisitos:
- Você está logado como um usuário habilitado
- Internet está desativada no dispositivo

### Passos:
1. **Passo A (Online):**
   - Faça login normalmente

2. **Passo B (Offline):**
   - Desative internet do dispositivo
   - Feche o app
   - Reabra o app

3. **Passo C (Resultado):**
   - App não consegue consultar Firestore
   - Carrega sessão do cache local

### Resultado Esperado:
⚠️ **Carregamento com cache**
- ✅ Usuário continua logado (usando dados em cache)
- ⚠️ Validação do Firestore é pulada (sem conexão)
- **Nota**: Se usuário foi desabilitado no Firestore, só será detectado quando internet voltar

---

## Teste 5: Alternar entre Habilitado e Desabilitado Múltiplas Vezes

### Pré-requisitos:
- Você tem acesso total à tela "Gerenciar Usuários"

### Passos:
1. Crie um usuário de teste: `teste123` com status "Habilitado"
2. Faça login como `teste123` → ✅ Deve funcionar
3. Vá para "Gerenciar Usuários"
4. Desabilite `teste123` → status muda para "Desabilitado"
5. Faça logout
6. Tente fazer login como `teste123` → ❌ Deve recusar com "Usuário inválido"
7. Faça login como admin
8. Vá para "Gerenciar Usuários"
9. Reabilite `teste123` → status muda para "Habilitado"
10. Faça logout
11. Tente fazer login como `teste123` → ✅ Deve funcionar novamente

### Resultado Esperado:
✅ **Ciclo completo funciona**
- Habilitado → Login funciona
- Desabilitado → Login bloqueado
- Reabilitado → Login funciona novamente

---

## Teste 6: Verificar Dados no Firestore

### Passos:
1. Abra [Firebase Console](https://console.firebase.google.com)
2. Selecione seu projeto
3. Vá para Firestore Database
4. Abra a collection `users`
5. Selecione um documento (ex: `admin`)
6. Verifique se existe o campo `ind_habilitado`

### Estrutura Esperada:
```
Document ID: admin
├── login: "admin"
├── role: "admin"
├── senha: "senha_do_admin"
└── ind_habilitado: "S"  ← Este campo deve existir
```

### Se o campo não existir:
- Crie o campo manualmente no Firestore
- Ou delete e recrie o usuário via app (isso criará o campo)

---

## Teste 7: Mensagens de Erro Variadas

### Teste cada mensagem de erro:

#### Erro: "Usuário não encontrado"
- **Como reproduzir**: Login com usuário inexistente (ex: `naoexiste`)
- **Esperado**: Mensagem vermelha com "Usuário não encontrado"

#### Erro: "Usuário inválido"
- **Como reproduzir**: Login com usuário onde `ind_habilitado = 'N'`
- **Esperado**: Mensagem vermelha com "Usuário inválido"

#### Erro: "Senha incorreta"
- **Como reproduzir**: Login com usuário correto mas senha errada
- **Esperado**: Mensagem vermelha com "Senha incorreta"

---

## Teste 8: Limpeza de Cache

### Pré-requisitos:
- Você está logado
- Smartphone com app instalado

### Passos:
1. Desabilite um usuário logado via "Gerenciar Usuários" (admin)
2. No app do usuário desabilitado:
   - Vá para Configurações do Android/iOS
   - Procure por "Armazenamento do App" ou similar
   - Clique em "Limpar Cache" ou "Limpar Dados"
3. Reabra o app

### Resultado Esperado:
- ❌ Cache foi deletado
- 🔐 Tela de login é exibida
- ❌ Tenta fazer login e recebe "Usuário inválido"

---

## Checklist de Validação

- [ ] Teste 1 - Usuário habilitado consegue fazer login
- [ ] Teste 2 - Usuário desabilitado não consegue fazer login
- [ ] Teste 3 - Desabilitar enquanto logado força logout na próxima abertura
- [ ] Teste 4 - Sem internet, usa cache local
- [ ] Teste 5 - Alternar habilitado/desabilitado funciona múltiplas vezes
- [ ] Teste 6 - Campo `ind_habilitado` existe no Firestore
- [ ] Teste 7 - Todas as mensagens de erro aparecem corretamente
- [ ] Teste 8 - Após limpar cache, é forçado logout

---

## Dúvidas Frequentes

### P: Onde vejo o valor de ind_habilitado no app?
**R**: Você não vê em tempo real, mas você pode gerenciar na tela "Gerenciar Usuários" onde aparece um dropdown "Status" com opções "Habilitado" ou "Desabilitado".

### P: Se um usuário é desabilitado, ele é deletado?
**R**: Não! O usuário continua no Firestore, apenas não consegue fazer login. É reversível.

### P: Quanto tempo leva para a desabilitação fazer efeito?
**R**: 
- Se o usuário fechar e reabrir o app: **imediato**
- Se o usuário está usando o app continuamente: **na próxima inicialização**

### P: O que acontece se o Firestore estiver fora do ar?
**R**: O app carrega o usuário do cache local e continua funcionando (offline mode).

---

## Troubleshooting

### Problema: Login ainda está sendo permitido mesmo após desabilitar
**Solução:**
1. Verifique se o campo `ind_habilitado` foi criado no Firestore
2. Verifique se o valor é exatamente `'N'` (não `'n'`, não `'No'`)
3. Limpe o cache do app e tente novamente
4. Verifique logs do console para erros

### Problema: Mensagem de erro não aparece
**Solução:**
1. Verifique se a tela de login está sendo exibida corretamente
2. Verifique se há alguma exceção sendo lançada no console
3. Tente desabilitar o usuário manualmente e testar novamente

### Problema: App não consulta Firestore
**Solução:**
1. Verifique conexão com internet
2. Verifique se Firebase está inicializado corretamente
3. Verifique permissões de Firestore (Firestore rules)

---

## Logs para Debugging

Se tiver dificuldade, adicione logs temporários em `auth_service.dart`:

```dart
// No método login()
print('ind_habilitado do Firestore: $ind_habilitado');

// No método loadUserFromPreferences()
print('Validando habilitação no Firestore: $username');
print('Resultado: $firestoreIndHabilitado');
```

Depois veja os logs no Flutter Debug Console enquanto testa.
