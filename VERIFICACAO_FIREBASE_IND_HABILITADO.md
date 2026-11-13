# Verificação Manual no Firestore - ind_habilitado

## 🔍 Como Verificar o Campo `ind_habilitado` no Firestore

### Passo 1: Acessar Firebase Console

1. Abra [https://console.firebase.google.com](https://console.firebase.google.com)
2. Selecione seu projeto
3. No menu lateral, clique em **"Firestore Database"**
4. Você deve ver a collection **`users`**

---

### Passo 2: Verificar um Documento Existente

1. Clique em collection **`users`**
2. Você verá uma lista de documentos (um para cada usuário)
3. Clique em um documento para abrir (ex: `admin`)

### Estrutura esperada:
```
Document ID: admin
├── login: "admin" (string)
├── role: "admin" (string)
├── senha: "abc123" (string)
└── ind_habilitado: "S" (string) ← Deve ter este campo
```

---

### Passo 3: Identificar Usuários Habilitados vs Desabilitados

**Habilitados** (conseguem fazer login):
```
ind_habilitado: "S"
```

**Desabilitados** (bloqueados):
```
ind_habilitado: "N"
```

---

## ➕ Se o Campo `ind_habilitado` NÃO Existir

### Opção 1: Adicionar Manualmente (Firestore Console)

1. Abra o documento em Firestore Console
2. Clique em **"Adicionar Campo"**
3. Preencha:
   - **Nome do Campo**: `ind_habilitado`
   - **Tipo**: `string`
   - **Valor**: `S` (para habilitar) ou `N` (para desabilitar)
4. Clique em "Salvar"

### Opção 2: Deletar e Recriar via App

1. No Firestore Console, delete o documento do usuário
2. No app (Gerenciar Usuários), clique "Adicionar Usuário"
3. Preencha os dados
4. Selecione Status "Habilitado"
5. Clique "Salvar"
6. O campo será criado automaticamente com `ind_habilitado: "S"`

### Opção 3: Editar via App

1. No app, vá para "Gerenciar Usuários"
2. Clique "Editar" no usuário
3. Mude o Status
4. Clique "Salvar"
5. O campo será atualizado/criado no Firestore

---

## 🔄 Como Alterar Status no Firestore (Manualmente)

1. Abra o documento do usuário no Firestore Console
2. Clique no campo `ind_habilitado`
3. Mude o valor:
   - De `"S"` para `"N"` (desabilitar)
   - De `"N"` para `"S"` (habilitar)
4. Clique fora do campo para salvar

**Efeito imediato:**
- ✅ Novo login será bloqueado
- ⚠️ Usuário logado continuará usando até fechar o app

---

## 📋 Checklist de Verificação no Firestore

- [ ] Collection `users` existe
- [ ] Pelo menos um documento (usuário) existe
- [ ] Documento tem campo `login`
- [ ] Documento tem campo `role`
- [ ] Documento tem campo `senha`
- [ ] Documento tem campo `ind_habilitado`
- [ ] Campo `ind_habilitado` contém `"S"` ou `"N"`

Se todos os itens acima estiverem ✅, a implementação está correta!

---

## 🧪 Teste Prático (30 segundos)

### Teste 1: Verificar Campo Existe
1. Firebase Console → Firestore Database
2. Collection `users` → Document `admin`
3. Procure por `ind_habilitado`
4. **Esperado**: Campo existe com valor `"S"` ou `"N"`

### Teste 2: Alterar e Testar
1. Firebase Console → Mude `ind_habilitado` para `"N"`
2. Tente fazer login no app com esse usuário
3. **Esperado**: Mensagem "Usuário inválido"

### Teste 3: Reabilitar
1. Firebase Console → Mude `ind_habilitado` para `"S"`
2. Tente fazer login no app com esse usuário
3. **Esperado**: Login funcionando

---

## 🐛 Troubleshooting

### "Não consigo ver o campo ind_habilitado"

**Causa**: Campo não foi criado

**Solução**:
1. **Criar manualmente**: Clique "Adicionar Campo" no Firestore Console
2. **Ou recriar usuário**: Delete via Firestore Console e recrie via app

### "Mudei para 'N' no Firestore mas ainda consigo logar"

**Causa**: App pode estar usando cache local

**Solução**:
1. Feche completamente o app
2. Limpe cache do app (Configurações → Apps → [seu app] → Limpar dados)
3. Reabra o app
4. Tente fazer login novamente

### "Campo existe mas tem valor diferente de 'S' ou 'N'"

**Exemplo de ERRO**: `ind_habilitado: "Sim"` ou `"SIM"`

**Solução**: 
1. Edite o campo no Firestore Console
2. Mude para exatamente `"S"` ou `"N"` (case-sensitive)

---

## 📊 Tabela de Referência

| Valor | Significado | Login Permitido? |
|-------|------------|-----------------|
| `"S"` | Habilitado | ✅ SIM |
| `"N"` | Desabilitado | ❌ NÃO |
| `"s"` | Erro (minúsculo) | ❌ NÃO |
| `"Sim"` | Erro (texto completo) | ❌ NÃO |
| `null` ou vazio | Campo não existe | ✅ SIM (padrão) |

**Regra Importante**: O valor deve ser exatamente `"S"` (maiúsculo) para permitir login!

---

## 💡 Dicas

1. **Query Firestore**: Se você quiser verificar quantos usuários estão habilitados:
   - Clique em "Query" na interface do Firestore
   - Adicione condição: `ind_habilitado == "S"`
   - Veja só os habilitados

2. **Copiar documento**: Para criar novo usuário com mesma estrutura:
   - Abra um documento existente
   - Copie todo o conteúdo
   - Crie novo documento
   - Cole o conteúdo
   - Mude `login` para novo nome

3. **Backup**: Antes de fazer alterações em massa:
   - Exporte os dados do Firestore
   - Firebase Console → Menu (três pontos) → Exportar

---

## 🔐 Estrutura Final Esperada

```
users/
├── admin
│   ├── login: "admin"
│   ├── role: "admin"
│   ├── senha: "password"
│   └── ind_habilitado: "S"
│
├── usuario1
│   ├── login: "usuario1"
│   ├── role: "user"
│   ├── senha: "password"
│   └── ind_habilitado: "S"
│
├── usuario2
│   ├── login: "usuario2"
│   ├── role: "user"
│   ├── senha: "password"
│   └── ind_habilitado: "N" ← Desabilitado
│
└── usuario3
    ├── login: "usuario3"
    ├── role: "user"
    ├── senha: "password"
    └── ind_habilitado: "S"
```

---

## ✅ Confirmação Final

Se você conseguiu:
- ✅ Ver o campo `ind_habilitado` em todos os documentos
- ✅ Alterar o valor de `"S"` para `"N"` no Firestore
- ✅ Receber "Usuário inválido" ao tentar fazer login com `"N"`
- ✅ Fazer login normalmente quando o valor é `"S"`

**PARABÉNS! A implementação está funcionando corretamente!** 🎉
